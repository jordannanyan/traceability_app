import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/add_purchasing.dart';
import 'package:traceability_app/models/edit_purchasing.dart';
import 'package:traceability_app/models/get_purchasing_by_farmer_id.dart';
import 'package:traceability_app/models/get_purchasing_by_id.dart';
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart';
// Both purchasing list models declare `Datum`; the prefix disambiguates the one
// the pending-row builder returns.
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart'
    as kth_purchasing;
import 'package:traceability_app/utils/utils.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

/// Hasil operasi offline-first (add/edit/delete)
class PurchasingOpResult {
  final bool appliedOnline; // langsung ke server sekarang
  final bool queued; // disimpan di outbox
  final int outboxCount; // jumlah task outbox saat ini
  final String message; // pesan untuk UI

  const PurchasingOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Hasil pemanggilan update status (offline-first).
class UpdateStatusResult {
  final bool appliedOnline; // status diterapkan ke server
  final bool queued; // request disimpan ke outbox (offline)
  final int outboxCount; // jumlah task outbox status
  final String message;

  const UpdateStatusResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Outbox item untuk UPDATE STATUS purchasing (tetap dipertahankan).
class _PurchasingStatusOutboxItem {
  final String id; // unik (epoch millis string)
  final int purchaseId;
  final String status; // 'verified' | 'not_verified' | 'failed'
  final int ts;

  _PurchasingStatusOutboxItem({
    required this.id,
    required this.purchaseId,
    required this.status,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'purchase_id': purchaseId,
    'status': status,
    'ts': ts,
  };


  factory _PurchasingStatusOutboxItem.fromJson(Map<String, dynamic> j) =>
      _PurchasingStatusOutboxItem(
        id: j['id'] as String,
        purchaseId: j['purchase_id'] as int,
        status: j['status'] as String,
        ts: j['ts'] as int,
      );
}

/// Outbox item untuk **CRUD** purchasing (add/edit/delete) – multipart/form-data.
class _PurchCrudOutboxItem {
  final String id; // unik (epoch millis string)
  final String method; // 'POST' | 'DELETE'
  final String endpoint; // '/purchasing' atau '/purchasing/{id}'
  final Map<String, dynamic>
  body; // payload form fields (string) + file path (string)
  final int? entityId; // purchaseId (untuk dedupe edit/delete)
  final int ts;

  _PurchCrudOutboxItem({
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

  factory _PurchCrudOutboxItem.fromJson(Map<String, dynamic> j) =>
      _PurchCrudOutboxItem(
        id: j['id'] as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int?,
        ts: j['ts'] as int,
      );
}

class PurchasingApi {
  late final Dio _dio;

  // ------------ Outbox (SharedPreferences) ------------
  // Status outbox
  static const String _statusOutboxKey = 'outbox_purch_status_v1';
  // CRUD outbox
  static const String _crudOutboxKey = 'outbox_purch_crud_v1';

  static bool _syncListenerStarted = false;

  // Serializes outbox pushes across concurrent triggers / transient instances.
  // Shared by the status and CRUD push methods (they run sequentially anyway).
  static final Lock _outboxLock = Lock();

  // ------------ Cache Purchasing by FARMER ------------
  static String _purchCacheKey(int farmerId) =>
      'cache_purchasing_by_farmer_$farmerId';
  static String _purchCacheTsKey(int farmerId) =>
      'cache_purchasing_by_farmer_${farmerId}_ts';

  // ------------ Cache Purchasing by KTH ------------
  static String _kthCacheKey(int kthId) => 'cache_purchasing_by_kth_$kthId';
  static String _kthCacheTsKey(int kthId) =>
      'cache_purchasing_by_kth_${kthId}_ts';

  PurchasingApi() {
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

    _dio.interceptors.add(SessionMonitor.watchdog());

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}');
            debugPrint('   headers: ${o.headers}');
            if (o.data != null) debugPrint('   body: ${_safeJson(o.data)}');
            h.next(o);
          },
          onResponse: (r, h) {
            debugPrint(
              '✅ ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.path}',
            );
            if (r.data != null) debugPrint('   resp: ${_safeJson(r.data)}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint(
              '❌ DioError ${e.type} for ${e.requestOptions.method} ${e.requestOptions.uri}',
            );
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

  // =================== Helpers umum ===================

  static String _safeJson(dynamic data) {
    if (data is FormData) {
      final fieldsMap = <String, String>{};
      for (final entry in data.fields) {
        fieldsMap[entry.key] = entry.value;
      }
      final filesInfo = <Map<String, String>>[];
      for (final entry in data.files) {
        final mf = entry.value;
        filesInfo.add({
          'key': entry.key,
          'filename': mf.filename ?? '(unknown)',
        });
      }
      return 'FormData(fields: ${jsonEncode(fieldsMap)}, files: ${jsonEncode(filesInfo)})';
    }
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

  Future<MultipartFile?> _maybeFile(dynamic src, String filename) async {
    if (src == null) return null;
    try {
      final path = (src is String) ? src : (src.path as String);
      if (path.isEmpty) return null;
      return await MultipartFile.fromFile(
        path,
        filename: filename,
        contentType: _photoMediaType(path),
      );
    } catch (_) {
      return null;
    }
  }

  static DioMediaType _photoMediaType(String path) {
    final lp = path.toLowerCase();
    if (lp.endsWith('.png')) return DioMediaType('image', 'png');
    if (lp.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lp.endsWith('.heic') || lp.endsWith('.heif')) {
      return DioMediaType('image', 'heic');
    }
    return DioMediaType('image', 'jpeg');
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  // =================== Outbox helpers: STATUS ===================

  Future<List<_PurchasingStatusOutboxItem>> _loadStatusOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_statusOutboxKey) ?? <String>[];
    final list =
        raw
            .map((s) => _PurchasingStatusOutboxItem.fromJson(jsonDecode(s)))
            .toList()
          ..sort((a, b) => a.ts.compareTo(b.ts)); // FIFO
    return list;
  }

  Future<void> _saveStatusOutbox(
    List<_PurchasingStatusOutboxItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _statusOutboxKey,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  List<_PurchasingStatusOutboxItem> _dedupeStatusByPurchaseId(
    List<_PurchasingStatusOutboxItem> l,
  ) {
    final map = <int, _PurchasingStatusOutboxItem>{};
    for (final it in l) {
      final prev = map[it.purchaseId];
      if (prev == null || it.ts >= prev.ts) map[it.purchaseId] = it;
    }
    final vals = map.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    return vals;
  }

  Future<int> getPurchasingStatusOutboxCount() async {
    final l = await _loadStatusOutbox();
    return l.length;
  }

  // =================== Outbox helpers: CRUD ===================

  Future<List<_PurchCrudOutboxItem>> _loadCrudOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_crudOutboxKey) ?? <String>[];
    final list =
        raw.map((s) => _PurchCrudOutboxItem.fromJson(jsonDecode(s))).toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }

  Future<void> _saveCrudOutbox(List<_PurchCrudOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _crudOutboxKey,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Dedupe untuk edit/delete per entityId → ambil entri terbaru.
  List<_PurchCrudOutboxItem> _dedupeCrudByEntityId(
    List<_PurchCrudOutboxItem> l,
  ) {
    final map = <int, _PurchCrudOutboxItem>{};
    final others = <_PurchCrudOutboxItem>[];
    for (final it in l) {
      if (it.entityId == null) {
        // create tidak punya id server: biarkan
        others.add(it);
      } else {
        final id = it.entityId!;
        final prev = map[id];
        if (prev == null || it.ts >= prev.ts) map[id] = it;
      }
    }
    final vals = map.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final all = <_PurchCrudOutboxItem>[...others, ...vals]
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return all;
  }

  Future<int> getPurchasingCrudOutboxCount() async {
    final l = await _loadCrudOutbox();
    return l.length;
  }

  /// Queued purchasing ops, ready for a list screen.
  ///
  /// Purchasing keeps **two** queues — CRUD and status changes — and both are
  /// pending work on the same rows, so they are merged into one index (a queued
  /// status change reads as a pending update). The status queue names its
  /// record `purchase_id` instead of the shared `entity_id`.
  ///
  /// Creates are not scoped to a KTH or farmer: the queued body carries
  /// `plot_id`, not an owner, and the mapping is not resolvable offline. In
  /// practice the add screen only writes online (`addPurchasing`), so the
  /// creates list is normally empty.
  static Future<PendingIndex> pendingIndex() async {
    final crud = await PendingOps.read(_crudOutboxKey);
    final status = await PendingOps.read(
      _statusOutboxKey,
      entityIdField: 'purchase_id',
      forceKind: PendingOpKind.update,
    );
    final merged = <PendingOp>[...crud, ...status]
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return PendingIndex.from(merged);
  }

  /// Seluruh antrean modul ini (CRUD + perubahan status), untuk halaman Data
  /// Offline. Keduanya digabung karena bagi pengguna sama saja: pekerjaan yang
  /// belum terkirim.
  static Future<List<PendingOp>> pendingOps() async {
    final crud = await PendingOps.read(_crudOutboxKey);
    final status = await PendingOps.read(
      _statusOutboxKey,
      entityIdField: 'purchase_id',
      forceKind: PendingOpKind.update,
    );
    return <PendingOp>[...crud, ...status]
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  /// Renders a queued create as a list row, with a synthetic negative id.
  static kth_purchasing.Datum pendingPurchasingRow(PendingOp op) =>
      kth_purchasing.Datum.fromJson({
    ...op.body,
    'id': op.localId,
    'created_at': op.queuedAt.toIso8601String(),
    'updated_at': op.queuedAt.toIso8601String(),
  });

  // =================== Cache helpers (FARMER) ===================

  Future<void> _savePurchasingCache({
    required int farmerId,
    required dynamic respData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_purchCacheKey(farmerId), jsonEncode(respData));
    await prefs.setInt(
      _purchCacheTsKey(farmerId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<GetPurchasingByFarmerId?> _loadPurchasingCacheModel(
    int farmerId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_purchCacheKey(farmerId));
    if (raw == null || raw.isEmpty) return null;
    return getPurchasingByFarmerIdFromJson(raw);
  }

  Future<DateTime?> getPurchasingCacheTime(int farmerId) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_purchCacheTsKey(farmerId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // =================== Cache helpers (KTH) ===================

  Future<void> _saveKthCache({
    required int kthId,
    required dynamic respData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kthCacheKey(kthId), jsonEncode(respData));
    await prefs.setInt(
      _kthCacheTsKey(kthId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<GetPurchasingByKthId?> _loadKthCacheModel(int kthId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kthCacheKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    return getPurchasingByKthIdFromJson(raw);
  }

  Future<DateTime?> getPurchasingByKthCacheTime(int kthId) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kthCacheTsKey(kthId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // =================== API Methods (GET) ===================

  Future<GetPurchasingByKthId> getPurchasingByKthId(int kthId) async {
    final opt = await _auth();
    final resp = await _dio.get('/purchasing/kth/$kthId', options: opt);
    if (resp.statusCode == 200) {
      return getPurchasingByKthIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to load purchasing data by KTH');
  }

  // alias lama
  Future<GetPurchasingByKthId> fetchPurchasingByKthId(int kthId) =>
      getPurchasingByKthId(kthId);

  /// CACHED-FIRST (OFFLINE-FIRST): by KTH
  Future<CachedResult<GetPurchasingByKthId>> getPurchasingByKthIdCached(
    int kthId,
  ) => readCachedFirst<GetPurchasingByKthId>(
    isOnline: _isOnline,
    request: () async =>
        _dio.get('/purchasing/kth/$kthId', options: await _auth()),
    parseAndCache: (resp) async {
      await _saveKthCache(kthId: kthId, respData: resp.data);
      return getPurchasingByKthIdFromJson(jsonEncode(resp.data));
    },
    readCache: () => _loadKthCacheModel(kthId),
    emptyValue: (_) => getPurchasingByKthIdFromJson(jsonEncode({'data': []})),
  );

  Future<GetPurchasingByFarmerId> getPurchasingByFarmerId(int farmerId) async {
    final opt = await _auth();
    final resp = await _dio.get('/purchasing/farmer/$farmerId', options: opt);
    if (resp.statusCode == 200) {
      return getPurchasingByFarmerIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch purchasing data by farmer');
  }

  Future<CachedResult<GetPurchasingByFarmerId>> getPurchasingByFarmerIdCached(
    int farmerId,
  ) => readCachedFirst<GetPurchasingByFarmerId>(
    isOnline: _isOnline,
    request: () async =>
        _dio.get('/purchasing/farmer/$farmerId', options: await _auth()),
    parseAndCache: (resp) async {
      await _savePurchasingCache(farmerId: farmerId, respData: resp.data);
      return getPurchasingByFarmerIdFromJson(jsonEncode(resp.data));
    },
    readCache: () => _loadPurchasingCacheModel(farmerId),
    emptyValue: (outcome) => GetPurchasingByFarmerId(
      status: outcome == RefreshOutcome.offlineCache
          ? 'offline-no-cache'
          : 'online-error-no-cache',
      data: [],
    ),
  );

  Future<GetPurchasingById> getPurchasingById(int id) async {
    final opt = await _auth();
    final resp = await _dio.get('/purchasing/$id', options: opt);
    if (resp.statusCode == 200) {
      return getPurchasingByIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch purchasing detail');
  }

  // =================== API Methods (Mutasi ONLINE murni) ===================

  Future<AddPurchasing> addPurchasing(Map<String, dynamic> requestData) async {
    final opt = await _auth(
      extraHeaders: {'Content-Type': 'multipart/form-data'},
    );
    final formData = await _buildPurchasingFormData(requestData);
    final resp = await _dio.post('/purchasing', data: formData, options: opt);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return addPurchasingFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to add purchasing');
  }

  Future<EditPurchasing> editPurchasing({
    required int id,
    required Map<String, dynamic> requestData,
  }) async {
    // Let Dio set multipart boundary automatically
    final opt = await _auth();

    final formData = await _buildPurchasingFormData(requestData);
    // Laravel method spoofing
    formData.fields.add(const MapEntry('_method', 'PUT'));

    // Use POST + _method=PUT for reliable multipart handling on Laravel
    final resp = await _dio.post(
      '/purchasing/$id',
      data: formData,
      options: opt,
    );

    if (resp.statusCode == 200) {
      return editPurchasingFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to edit purchasing');
  }

  Future<String> deletePurchasing(int id) async {
    final opt = await _auth();
    final resp = await _dio.delete('/purchasing/$id', options: opt);
    if (resp.statusCode == 200) {
      return resp.data['message']?.toString() ?? 'Deleted successfully';
    }
    _throwHttp(resp, 'Failed to delete purchasing');
  }

  // =================== API Methods (Mutasi OFFLINE-FIRST) ===================

  /// Tambah purchasing offline-first
  Future<PurchasingOpResult> addPurchasingOfflineFirst(
    Map<String, dynamic> requestData,
  ) async {
    final online = await _isOnline();

    if (online) {
      await addPurchasing(requestData);
      final pushedStatus = await pushPurchasingStatusOutbox();
      final pushedCrud = await pushPurchasingOutbox();
      final count = await getPurchasingCrudOutboxCount();
      return PurchasingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: (pushedStatus + pushedCrud) > 0
            ? 'Tersinkron: ${pushedStatus + pushedCrud} aksi tertunda.'
            : 'Pembelian ditambahkan.',
      );
    }

    // OFFLINE → queue POST /purchasing
    final list = await _loadCrudOutbox();
    list.add(
      _PurchCrudOutboxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: 'POST',
        endpoint: '/purchasing',
        body: _stringifyBody(requestData),
        entityId: null,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _saveCrudOutbox(list);

    return PurchasingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: list.length,
      message: 'Tersimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Edit purchasing offline-first
  Future<PurchasingOpResult> editPurchasingOfflineFirst({
    required int id,
    required Map<String, dynamic> requestData,
  }) async {
    final online = await _isOnline();

    if (online) {
      await editPurchasing(id: id, requestData: requestData);
      final pushedStatus = await pushPurchasingStatusOutbox();
      final pushedCrud = await pushPurchasingOutbox();
      final count = await getPurchasingCrudOutboxCount();
      return PurchasingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: (pushedStatus + pushedCrud) > 0
            ? 'Tersinkron: ${pushedStatus + pushedCrud} aksi tertunda.'
            : 'Pembelian diperbarui.',
      );
    }

    // OFFLINE → queue POST /purchasing/{id} dengan _method=PUT
    final list = await _loadCrudOutbox();
    final body = _stringifyBody(requestData);
    body['_method'] = 'PUT';

    list.add(
      _PurchCrudOutboxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: 'POST',
        endpoint: '/purchasing/$id',
        body: body,
        entityId: id,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final deduped = _dedupeCrudByEntityId(list);
    await _saveCrudOutbox(deduped);

    return PurchasingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Hapus purchasing offline-first
  Future<PurchasingOpResult> deletePurchasingOfflineFirst(int id) async {
    final online = await _isOnline();

    if (online) {
      await deletePurchasing(id);
      final pushedStatus = await pushPurchasingStatusOutbox();
      final pushedCrud = await pushPurchasingOutbox();
      final count = await getPurchasingCrudOutboxCount();
      return PurchasingOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: (pushedStatus + pushedCrud) > 0
            ? 'Tersinkron: ${pushedStatus + pushedCrud} aksi tertunda.'
            : 'Pembelian dihapus.',
      );
    }

    // OFFLINE → queue DELETE /purchasing/{id}
    final list = await _loadCrudOutbox();
    list.add(
      _PurchCrudOutboxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: 'DELETE',
        endpoint: '/purchasing/$id',
        body: const {},
        entityId: id,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final deduped = _dedupeCrudByEntityId(list);
    await _saveCrudOutbox(deduped);

    return PurchasingOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  // =================== PUSH Outbox ===================

  /// Dorong seluruh outbox **status** ke server.
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushPurchasingStatusOutbox() =>
      _outboxLock.synchronized(_pushPurchasingStatusOutboxLocked);

  Future<int> _pushPurchasingStatusOutboxLocked() async {
    final online = await _isOnline();
    if (!online) return 0;

    var list = await _loadStatusOutbox();
    if (list.isEmpty) return 0;

    int success = 0;
    for (final item in List<_PurchasingStatusOutboxItem>.from(list)) {
      try {
        await _updatePurchasingStatusOnline(
          id: item.purchaseId,
          status: item.status,
        );
        success++;
        list.removeWhere((e) => e.id == item.id);
        await _saveStatusOutbox(list);
      } catch (e) {
        // Poison (invalid 4xx) → drop and keep going so one bad item never
        // blocks the queue; otherwise (network/5xx/auth/timeout) stop & retry.
        if (isPoisonOutboxError(e)) {
          list.removeWhere((x) => x.id == item.id);
          await _saveStatusOutbox(list);
          continue;
        }
        break;
      }
    }
    return success;
  }

  /// Dorong seluruh outbox **CRUD** ke server.
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushPurchasingOutbox() =>
      _outboxLock.synchronized(_pushPurchasingOutboxLocked);

  Future<int> _pushPurchasingOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadCrudOutbox();
    if (list.isEmpty) return 0;

    int success = 0;
    for (final item in List<_PurchCrudOutboxItem>.from(list)) {
      try {
        await _pushCrudItemOnline(item);
        success++;
        list.removeWhere((e) => e.id == item.id);
        await _saveCrudOutbox(list);
      } catch (e) {
        // Poison (invalid 4xx) → drop and keep going so one bad item never
        // blocks the queue; otherwise (network/5xx/auth/timeout) stop & retry.
        if (isPoisonOutboxError(e)) {
          list.removeWhere((x) => x.id == item.id);
          await _saveCrudOutbox(list);
          continue;
        }
        break;
      }
    }
    return success;
  }

  Future<void> _pushCrudItemOnline(_PurchCrudOutboxItem it) async {
    if (it.method == 'POST' && it.endpoint == '/purchasing') {
      // CREATE (multipart)
      final opt = await _auth(
        extraHeaders: {'Content-Type': 'multipart/form-data'},
      );
      final form = await _buildPurchasingFormData(it.body);
      final resp = await _dio.post(it.endpoint, data: form, options: opt);
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      _throwHttp(resp, 'Failed to add purchasing (push)');
    } else if (it.method == 'POST' && it.endpoint.startsWith('/purchasing/')) {
      // EDIT (method spoofing, multipart)
      final opt = await _auth(
        extraHeaders: {'Content-Type': 'multipart/form-data'},
      );
      final form = await _buildPurchasingFormData(it.body);
      if (!form.fields.any((e) => e.key == '_method')) {
        form.fields.add(const MapEntry('_method', 'PUT'));
      }
      final resp = await _dio.post(it.endpoint, data: form, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update purchasing (push)');
    } else if (it.method == 'DELETE' &&
        it.endpoint.startsWith('/purchasing/')) {
      final opt = await _auth();
      final resp = await _dio.delete(it.endpoint, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete purchasing (push)');
    } else {
      throw Exception('Unsupported outbox item: ${it.method} ${it.endpoint}');
    }
  }

  /// Listener global: panggil sekali (mis. setelah login) agar outbox otomatis dipush saat online.
  static Future<void> startAutoSyncListener() async {
    if (_syncListenerStarted) return;
    _syncListenerStarted = true;

    Future<void> flush() async {
      try {
        final api = PurchasingApi();
        await api.pushPurchasingStatusOutbox();
        await api.pushPurchasingOutbox();
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (each push self-guards on connectivity).
    await flush();
  }

  // =================== UPDATE STATUS (OFFLINE-FIRST) ===================

  Future<UpdateStatusResult> updatePurchasingStatusOfflineFirst({
    required int id,
    required String status,
  }) async {
    final normalized = status.trim().toLowerCase();
    const allowed = {'verified', 'not_verified', 'failed'};
    if (!allowed.contains(normalized)) {
      throw Exception('Invalid status: $status');
    }

    final online = await _isOnline();

    if (online) {
      await _updatePurchasingStatusOnline(id: id, status: normalized);
      final pushed = await pushPurchasingStatusOutbox(); // dorong sisa
      final count = await getPurchasingStatusOutboxCount();
      return UpdateStatusResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0
            ? 'Tersinkron: $pushed aksi tertunda.'
            : 'Status diperbarui.',
      );
    }

    // OFFLINE → queue
    final list = await _loadStatusOutbox();
    list.add(
      _PurchasingStatusOutboxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        purchaseId: id,
        status: normalized,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final deduped = _dedupeStatusByPurchaseId(list);
    await _saveStatusOutbox(deduped);

    return const UpdateStatusResult(
      appliedOnline: false,
      queued: true,
      outboxCount: 0, // tidak terlalu penting untuk status
      message: 'Tersimpan offline. Akan disinkronkan saat online.',
    );
  }

  Future<EditPurchasing> _updatePurchasingStatusOnline({
    required int id,
    required String status,
  }) async {
    try {
      final opt = await _auth(
        extraHeaders: {'Content-Type': 'application/json'},
      );
      final resp = await _dio.put(
        '/purchasing/$id',
        data: {'status': status},
        options: opt,
      );
      if (resp.statusCode == 200) {
        return editPurchasingFromJson(jsonEncode(resp.data));
      }
      _throwHttp(resp, 'Failed to update status');
    } on DioException catch (e) {
      // fallback POST + _method=PUT (beberapa server menolak PUT JSON)
      final code = e.response?.statusCode ?? 0;
      if (code == 405 ||
          code == 415 ||
          e.type == DioExceptionType.badResponse) {
        final opt2 = await _auth(
          extraHeaders: {'Content-Type': 'multipart/form-data'},
        );
        final form = FormData.fromMap({'status': status, '_method': 'PUT'});
        final resp2 = await _dio.post(
          '/purchasing/$id',
          data: form,
          options: opt2,
        );
        if (resp2.statusCode == 200) {
          return editPurchasingFromJson(jsonEncode(resp2.data));
        }
        _throwHttp(resp2, 'Failed to update status (fallback)');
      }
      if (e.response != null) {
        throw Exception(
          'HTTP ${e.response?.statusCode}: ${_safeJson(e.response?.data)}',
        );
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  // =================== Helpers form-data ===================

  /// Normalisasi map request (campuran int/double/string/File?) → map string + path
  Map<String, dynamic> _stringifyBody(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) return;
      // simpan path string untuk file, string biasa untuk scalar
      if (k == 'upload_proof_value' ||
          k == 'upload_proof_deduction' ||
          k == 'upload_proof_payment') {
        if (v is String) {
          out[k] = v;
        } else {
          try {
            out[k] = v.path?.toString();
          } catch (_) {
            // ignore
          }
        }
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

  // 2) --- form-data: attach the signature_image file ---
  Future<FormData> _buildPurchasingFormData(
    Map<String, dynamic> requestData,
  ) async {
    final formData = FormData();

    // Scalars
    for (final key in const [
      'date',
      'plot_id',
      'warehouse_id',
      'commodities_id',
      'quantity',
      'grade_id',
      'price_per_kg',
      'value_purchased',
      'deduction',
      'net_payment',
      '_method', // optional (edit / outbox)
    ]) {
      final v = requestData[key];
      if (v != null && v.toString().isNotEmpty) {
        formData.fields.add(MapEntry(key, v.toString()));
      }
    }

    // Files
    Future<void> attach(String field, String filename) async {
      final src = requestData[field];
      final mf = await _maybeFile(src, filename);
      if (mf != null) formData.files.add(MapEntry(field, mf));
    }

    await attach('upload_proof_value', 'proof_value.jpg');
    await attach('upload_proof_deduction', 'proof_deduction.jpg');
    await attach('upload_proof_payment', 'proof_payment.jpg');

    // NEW: signature image
    await attach('signature_image', 'signature.png');

    return formData;
  }
}
