import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/get_selling_by_id.dart';
import 'package:traceability_app/models/get_selling_by_kth_id.dart';
import 'package:traceability_app/utils/utils.dart';

/// Hasil operasi offline-first
class SellingOpResult {
  final bool appliedOnline; // langsung diterapkan ke server?
  final bool queued;        // disimpan ke outbox?
  final int outboxCount;    // jumlah task outbox saat ini
  final String message;     // pesan untuk UI

  const SellingOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Item antrian mutasi selling
class _SellingOutboxItem {
  final String id;        // unik (epoch millis string)
  final String method;    // 'POST' | 'PUT' (spoof via POST) | 'DELETE'
  final String endpoint;  // '/selling' atau '/selling/{id}'
  final Map<String, dynamic> body; // payload JSON (bisa kosong)
  final int? entityId;    // id selling jika ada (untuk dedupe edit/delete)
  final int ts;           // timestamp millis

  _SellingOutboxItem({
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

  factory _SellingOutboxItem.fromJson(Map<String, dynamic> j) => _SellingOutboxItem(
        id: j['id'] as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int?,
        ts: j['ts'] as int,
      );
}

class SellingApi {
  late final Dio _dio;

  // ========= Outbox (SharedPreferences) =========
  static const String _outboxKey = 'outbox_selling_v1';
  static bool _syncListenerStarted = false;

  // Serializes outbox pushes across concurrent triggers / transient instances.
  static final Lock _outboxLock = Lock();

  // ========= Cache (list by KTH) =========
  static String _cacheKthKey(int kthId) => 'cache_selling_by_kth_$kthId';
  static String _cacheKthTsKey(int kthId) => 'cache_selling_by_kth_${kthId}_ts';

  SellingApi() {
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

  // =============== Helpers umum ===============

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

  Never _throwHttp(Response<dynamic> resp, [String fallback = 'HTTP error']) {
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

  // =============== Outbox helpers ===============

  Future<List<_SellingOutboxItem>> _loadOutbox() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_outboxKey) ?? <String>[];
    final list = raw.map((s) => _SellingOutboxItem.fromJson(jsonDecode(s))).toList();
    list.sort((a, b) => a.ts.compareTo(b.ts)); // FIFO
    return list;
  }

  Future<void> _saveOutbox(List<_SellingOutboxItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_outboxKey, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  /// Dedupe edit/delete per entityId → sisakan entri terbaru. POST create tidak di-dedupe.
  List<_SellingOutboxItem> _dedupeByEntityId(List<_SellingOutboxItem> l) {
    final map = <int, _SellingOutboxItem>{};
    final creates = <_SellingOutboxItem>[];
    for (final it in l) {
      if (it.entityId == null) {
        creates.add(it); // create
      } else {
        final id = it.entityId!;
        final prev = map[id];
        if (prev == null || it.ts >= prev.ts) map[id] = it;
      }
    }
    final merged = <_SellingOutboxItem>[...creates, ...map.values]
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return merged;
  }

  Future<int> getSellingOutboxCount() async {
    final l = await _loadOutbox();
    return l.length;
  }

  // =============== Cache helpers (KTH list) ===============

  Future<void> _saveKthCache({
    required int kthId,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKthKey(kthId), jsonEncode(data));
    await p.setInt(_cacheKthTsKey(kthId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetSellingByKthId?> _loadKthCacheModel(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKthKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    return getSellingByKthIdFromJson(raw);
  }

  Future<DateTime?> getSellingByKthCacheTime(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheKthTsKey(kthId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // =============== API (GET) ===============

  /// Online murni (tetap dipertahankan)
  Future<GetSellingByKthId> getSellingByKthId(int kthId) async {
    final opt = await _auth();
    final resp = await _dio.get('/selling/kth/$kthId', options: opt);
    if (resp.statusCode == 200) {
      return getSellingByKthIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch selling data');
  }

  /// Cached-first (offline-first)
  Future<GetSellingByKthId> getSellingByKthIdCached(int kthId) async {
    final online = await _isOnline();

    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/selling/kth/$kthId', options: opt);
        if (resp.statusCode == 200) {
          await _saveKthCache(kthId: kthId, data: resp.data);
          return getSellingByKthIdFromJson(jsonEncode(resp.data));
        }
        final cached = await _loadKthCacheModel(kthId);
        if (cached != null) return cached;
        _throwHttp(resp, 'Failed to fetch selling data');
      } catch (_) {
        final cached = await _loadKthCacheModel(kthId);
        if (cached != null) return cached;
        return GetSellingByKthId(status: 'online-error-no-cache', data: []);
      }
    } else {
      final cached = await _loadKthCacheModel(kthId);
      if (cached != null) return cached;
      return GetSellingByKthId(status: 'offline-no-cache', data: []);
    }
  }

  /// Detail (online). Kalau mau, bisa ditambah versi cached per-id.
  Future<GetSellingById> getSellingById(int id) async {
    final opt = await _auth();
    final resp = await _dio.get('/selling/$id', options: opt);
    if (resp.statusCode == 200) {
      return getSellingByIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch selling data');
  }

  // =============== API (Mutasi ONLINE murni — internal/kompat) ===============

  /// Tambah penjualan (schema fleksibel via map; sesuaikan key sesuai backend)
  Future<Map<String, dynamic>> addSelling(Map<String, dynamic> requestData) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
    final resp = await _dio.post('/selling', data: jsonEncode(requestData), options: opt);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return (resp.data as Map).cast<String, dynamic>();
    }
    _throwHttp(resp, 'Failed to add selling');
  }

  /// Edit penjualan (method spoofing PUT via POST)
  Future<Map<String, dynamic>> editSelling(int id, Map<String, dynamic> requestData) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
    final data = {'_method': 'PUT', ...requestData};
    final resp = await _dio.post('/selling/$id', data: jsonEncode(data), options: opt);
    if (resp.statusCode == 200) {
      return (resp.data as Map).cast<String, dynamic>();
    }
    _throwHttp(resp, 'Failed to update selling');
  }

  Future<String> deleteSelling(int id) async {
    final opt = await _auth();
    final resp = await _dio.delete('/selling/$id', options: opt);
    if (resp.statusCode == 200) {
      return resp.data['message']?.toString() ?? 'Selling deleted successfully';
    }
    _throwHttp(resp, 'Failed to delete selling');
  }

  // =============== API (Mutasi OFFLINE-FIRST — dipakai UI) ===============

  Future<SellingOpResult> addSellingOfflineFirst(Map<String, dynamic> requestData) async {
    if (await _isOnline()) {
      await addSelling(requestData);
      final pushed = await pushSellingOutbox();
      final count = await getSellingOutboxCount();
      return SellingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Penjualan ditambahkan.',
      );
    }

    final list = await _loadOutbox();
    list.add(_SellingOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST',
      endpoint: '/selling',
      body: requestData,
      entityId: null, // create belum punya id server
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    await _saveOutbox(list);

    return SellingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: list.length,
      message: 'Tersimpan offline. Akan disinkronkan saat online.',
    );
  }

  Future<SellingOpResult> editSellingOfflineFirst(int id, Map<String, dynamic> requestData) async {
    if (await _isOnline()) {
      await editSelling(id, requestData);
      final pushed = await pushSellingOutbox();
      final count = await getSellingOutboxCount();
      return SellingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Penjualan diperbarui.',
      );
    }

    final list = await _loadOutbox();
    list.add(_SellingOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST',                 // spoof PUT
      endpoint: '/selling/$id',
      body: {'_method': 'PUT', ...requestData},
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return SellingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  Future<SellingOpResult> deleteSellingOfflineFirst(int id) async {
    if (await _isOnline()) {
      await deleteSelling(id);
      final pushed = await pushSellingOutbox();
      final count = await getSellingOutboxCount();
      return SellingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Penjualan dihapus.',
      );
    }

    final list = await _loadOutbox();
    list.add(_SellingOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'DELETE',
      endpoint: '/selling/$id',
      body: const {},
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return SellingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Dorong semua outbox saat online. Return jumlah task sukses.
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushSellingOutbox() =>
      _outboxLock.synchronized(_pushSellingOutboxLocked);

  Future<int> _pushSellingOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadOutbox();
    if (list.isEmpty) return 0;

    int success = 0;

    for (final item in List<_SellingOutboxItem>.from(list)) {
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

  Future<void> _pushItemOnline(_SellingOutboxItem it) async {
    final optJson = await _auth(extraHeaders: {'Content-Type': 'application/json'});

    if (it.method == 'POST' && it.endpoint == '/selling') {
      final resp = await _dio.post(it.endpoint, data: jsonEncode(it.body), options: optJson);
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      _throwHttp(resp, 'Failed to add selling (push)');
    } else if (it.method == 'POST' && it.endpoint.startsWith('/selling/')) {
      final resp = await _dio.post(it.endpoint, data: jsonEncode(it.body), options: optJson);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update selling (push)');
    } else if (it.method == 'DELETE' && it.endpoint.startsWith('/selling/')) {
      final opt = await _auth();
      final resp = await _dio.delete(it.endpoint, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete selling (push)');
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
        await SellingApi().pushSellingOutbox();
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (pushSellingOutbox self-guards on connectivity).
    await flush();
  }
}
