import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/edit_warehouse.dart';
import 'package:traceability_app/models/get_warehouse.by_id.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart';
import 'package:traceability_app/utils/utils.dart';

/// Hasil operasi offline-first
class WarehouseOpResult {
  final bool appliedOnline; // diterapkan langsung ke server?
  final bool queued;        // ditaruh ke outbox?
  final int outboxCount;    // jumlah task di outbox
  final String message;     // pesan singkat untuk UI

  const WarehouseOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Item outbox untuk mutasi gudang
class _WarehouseOutboxItem {
  final String id;           // unik (epoch millis string)
  final String method;       // 'POST' (spoof PUT) | 'DELETE'
  final String endpoint;     // '/warehouse/{id}'
  final Map<String, dynamic> body; // payload JSON
  final int entityId;        // warehouse id
  final int ts;              // timestamp millis

  _WarehouseOutboxItem({
    required this.id,
    required this.method,
    required this.endpoint,
    required this.body,
    required this.entityId,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'entity_id': entityId,
        'ts': ts,
      };

  factory _WarehouseOutboxItem.fromJson(Map<String, dynamic> j) => _WarehouseOutboxItem(
        id: j['id'] as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int,
        ts: j['ts'] as int,
      );
}

class WarehouseApi {
  late final Dio _dio;

  // ===== Outbox =====
  static const String _outboxKey = 'outbox_warehouse_v1';
  static bool _syncListenerStarted = false;

  // Serializes outbox pushes across concurrent triggers / transient instances.
  static final Lock _outboxLock = Lock();

  // ===== Cache (list by KTH) =====
  static String _cacheKthKey(int kthId) => 'cache_warehouse_by_kth_$kthId';
  static String _cacheKthTsKey(int kthId) => 'cache_warehouse_by_kth_${kthId}_ts';

  WarehouseApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}');
            if (o.data != null) debugPrint('   body: ${_safeJson(o.data)}');
            h.next(o);
          },
          onResponse: (r, h) {
            debugPrint('✅ ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.path}');
            if (r.data != null) debugPrint('   resp: ${_safeJson(r.data)}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint('❌ DioError ${e.type} for ${e.requestOptions.method} ${e.requestOptions.uri}');
            debugPrint('   message: ${e.message}');
            if (e.response != null) {
              debugPrint('   status: ${e.response?.statusCode}');
              debugPrint('   resp: ${_safeJson(e.response?.data)}');
            }
            h.next(e);
          },
        ),
      );
    }
  }

  // ===== Helpers umum =====

  static String _safeJson(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<Options> _auth({Map<String, String>? extraHeaders}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) throw Exception('Token not found. Please log in again.');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };
    return Options(headers: headers);
  }

  Never _throwHttp(Response resp, [String fallback = 'HTTP error']) {
    // DioException (with the response) so outbox push loops can classify the
    // HTTP status. The client uses `validateStatus: (_) => true`, so non-2xx
    // must be converted here or it surfaces as an unclassified plain Exception.
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: '$fallback (HTTP ${resp.statusCode}): ${_safeJson(resp.data)}',
    );
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ===== Outbox helpers =====

  Future<List<_WarehouseOutboxItem>> _loadOutbox() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_outboxKey) ?? <String>[];
    final list = raw.map((s) => _WarehouseOutboxItem.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts)); // FIFO
    return list;
  }

  Future<void> _saveOutbox(List<_WarehouseOutboxItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_outboxKey, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  /// Dedupe per entityId (untuk edit/delete), sisakan entri terbaru
  List<_WarehouseOutboxItem> _dedupeByEntityId(List<_WarehouseOutboxItem> l) {
    final map = <int, _WarehouseOutboxItem>{};
    for (final it in l) {
      final prev = map[it.entityId];
      if (prev == null || it.ts >= prev.ts) map[it.entityId] = it;
    }
    final vals = map.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    return vals;
  }

  Future<int> getWarehouseOutboxCount() async {
    final l = await _loadOutbox();
    return l.length;
  }

  /// Queued warehouse ops, ready for the list screen. Warehouses are only ever
  /// edited (never created) from the app, so this yields pending changes on
  /// existing rows rather than new ones.
  static Future<PendingIndex> pendingIndex() async =>
      PendingIndex.from(await PendingOps.read(_outboxKey));

  // ===== Cache helpers =====

  Future<void> _saveKthCache({
    required int kthId,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKthKey(kthId), jsonEncode(data));
    await p.setInt(_cacheKthTsKey(kthId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetWarehouseByKthId?> _loadKthCacheModel(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKthKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    return getWarehouseByKthIdFromJson(raw);
  }

  Future<DateTime?> getWarehouseByKthCacheTime(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheKthTsKey(kthId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ===== API (GET) =====

  /// Online murni (dipertahankan)
  Future<GetWarehouseByKthId> getWarehouseByKthId(int kthId) async {
    final opt = await _auth();
    final resp = await _dio.get('/warehouse/kth/$kthId', options: opt);
    if (resp.statusCode == 200) {
      return getWarehouseByKthIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch warehouse data');
  }

  /// Cached-first (offline-first) — untuk list gudang per KTH
// Cached-first (offline-first) — untuk list gudang per KTH
Future<GetWarehouseByKthId> getWarehouseByKthIdCached(int kthId) async {
  final online = await _isOnline();

  if (online) {
    try {
      final opt = await _auth();
      final resp = await _dio.get('/warehouse/kth/$kthId', options: opt);
      if (resp.statusCode == 200) {
        await _saveKthCache(kthId: kthId, data: resp.data);
        return getWarehouseByKthIdFromJson(jsonEncode(resp.data));
      }
      // server non-200 → coba cache
      final cached = await _loadKthCacheModel(kthId);
      if (cached != null) return cached;

      // fallback: gunakan message, bukan status
      _throwHttp(resp, 'Failed to fetch warehouse data');
    } catch (_) {
      // network error → fallback cache (kalau ada)
      final cached = await _loadKthCacheModel(kthId);
      if (cached != null) return cached;

      // tidak ada cache: kembalikan objek kosong dengan message penanda
      return GetWarehouseByKthId(
        message: 'online-error-no-cache',
        data: [],
      );
    }
  } else {
    final cached = await _loadKthCacheModel(kthId);
    if (cached != null) return cached;

    // tidak ada cache saat offline
    return GetWarehouseByKthId(
      message: 'offline-no-cache',
      data: [],
    );
  }
}

  /// Detail (online). Kalau mau, bisa ditambah cache per-id.
  Future<GetWarehouseById> getWarehouseById(int id) async {
    final opt = await _auth();
    final resp = await _dio.get('/warehouse/$id', options: opt);
    if (resp.statusCode == 200) {
      return getWarehouseByIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch warehouse detail');
  }

  // ===== API (Mutasi ONLINE murni — kompat) =====

  Future<EditWarehouse> editWarehouse({
    required int id,
    required String warehouseName,
    required String address,
    required int kthId,
  }) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
    final resp = await _dio.post(
      '/warehouse/$id?_method=PUT',
      data: jsonEncode({
        'warehouse_name': warehouseName,
        'address': address,
        'kth_id': kthId,
      }),
      options: opt,
    );
    if (resp.statusCode == 200) {
      return editWarehouseFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to update warehouse');
  }

  Future<String> deleteWarehouse(int id) async {
    final opt = await _auth();
    final resp = await _dio.delete('/warehouse/$id', options: opt);
    if (resp.statusCode == 200) {
      return resp.data['message']?.toString() ?? 'Warehouse deleted successfully';
    }
    _throwHttp(resp, 'Failed to delete warehouse');
  }

  // ===== API (Mutasi OFFLINE-FIRST — dipakai UI) =====

  /// Edit gudang offline-first (akan antri jika offline)
  Future<WarehouseOpResult> editWarehouseOfflineFirst({
    required int id,
    required String warehouseName,
    required String address,
    required int kthId,
  }) async {
    if (await _isOnline()) {
      await editWarehouse(id: id, warehouseName: warehouseName, address: address, kthId: kthId);
      final pushed = await pushWarehouseOutbox();
      final count = await getWarehouseOutboxCount();
      return WarehouseOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Gudang diperbarui.',
      );
    }

    final list = await _loadOutbox();
    list.add(_WarehouseOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST', // spoof PUT
      endpoint: '/warehouse/$id',
      body: {
        '_method': 'PUT',
        'warehouse_name': warehouseName,
        'address': address,
        'kth_id': kthId,
      },
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return WarehouseOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Hapus gudang offline-first
  Future<WarehouseOpResult> deleteWarehouseOfflineFirst(int id) async {
    if (await _isOnline()) {
      await deleteWarehouse(id);
      final pushed = await pushWarehouseOutbox();
      final count = await getWarehouseOutboxCount();
      return WarehouseOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Gudang dihapus.',
      );
    }

    final list = await _loadOutbox();
    list.add(_WarehouseOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'DELETE',
      endpoint: '/warehouse/$id',
      body: const {},
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return WarehouseOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Dorong semua outbox saat online. Return jumlah task sukses.
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushWarehouseOutbox() =>
      _outboxLock.synchronized(_pushWarehouseOutboxLocked);

  Future<int> _pushWarehouseOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadOutbox();
    if (list.isEmpty) return 0;

    int success = 0;

    for (final item in List<_WarehouseOutboxItem>.from(list)) {
      try {
        await _pushItemOnline(item);
        success++;
        list.removeWhere((e) => e.id == item.id);
        await _saveOutbox(list);
      } catch (e) {
        // Poison (invalid 4xx) → drop and keep going so one bad item never
        // blocks the queue; otherwise (network/5xx/auth/timeout) stop & retry.
        if (isPoisonOutboxError(e)) {
          list.removeWhere((x) => x.id == item.id);
          await _saveOutbox(list);
          continue;
        }
        break;
      }
    }
    return success;
  }

  Future<void> _pushItemOnline(_WarehouseOutboxItem it) async {
    if (it.method == 'POST' && it.endpoint.startsWith('/warehouse/')) {
      final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
      final resp = await _dio.post(it.endpoint, data: jsonEncode(it.body), options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update warehouse (push)');
    } else if (it.method == 'DELETE' && it.endpoint.startsWith('/warehouse/')) {
      final opt = await _auth();
      final resp = await _dio.delete(it.endpoint, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete warehouse (push)');
    } else {
      throw Exception('Unsupported outbox item: ${it.method} ${it.endpoint}');
    }
  }

  /// Listener global: panggil sekali (mis. setelah login) agar outbox auto-sync saat online.
  static Future<void> startAutoSyncListener() async {
    if (_syncListenerStarted) return;
    _syncListenerStarted = true;

    Future<void> flush() async {
      try {
        await WarehouseApi().pushWarehouseOutbox();
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (pushWarehouseOutbox self-guards on connectivity).
    await flush();
  }
}
