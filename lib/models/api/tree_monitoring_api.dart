// lib/models/api/tree_monitoring_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/tree_monitoring.dart';
import 'package:traceability_app/utils/utils.dart'; // AppConstants.baseUrl
import 'package:traceability_app/models/api/session_monitor.dart';

class TreeMonitoringOpResult {
  final bool appliedOnline;
  final bool queued;
  final int outboxCount;
  final String message;

  const TreeMonitoringOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

class _MonOutboxItem {
  final String id;        // epoch millis string
  final String method;    // 'POST' | 'PUT' | 'DELETE'
  final String endpoint;  // '/trees/{treeId}/monitorings' | '/tree-monitorings/{id}'
  final Map<String, dynamic> body; // scalar string + optional 'photo_path'
  final int? entityId;    // monitoring id (for update/delete dedupe)
  final int ts;           // timestamp

  _MonOutboxItem({
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

  factory _MonOutboxItem.fromJson(Map<String, dynamic> j) => _MonOutboxItem(
        id: j['id'] as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int?,
        ts: j['ts'] as int,
      );
}

class TreeMonitoringApi {
  late final Dio _dio;

  // Base origin for public storage files (Laravel `public/storage` symlink).
  static const String storageBaseUrl =
      'https://app.nbsvworldwide.com';

  /// Normalise a stored photo path. DB stores paths inconsistently
  /// (`/storage/trees/x.jpg`, `storage/x.jpg`, `/x.jpg`, or `x.jpg`); always
  /// produce a URL with a single `/storage/` segment.
  static String? resolvePhotoUrl(String? stored) {
    if (stored == null) return null;
    String s = stored.trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      final u = Uri.tryParse(s);
      if (u == null) return s;
      if (u.host == 'localhost' || u.host == '127.0.0.1') {
        return Uri(
          scheme: 'https',
          host: 'app.nbsvworldwide.com',
          path: u.path,
        ).toString();
      }
      return s;
    }

    s = s.replaceFirst(RegExp(r'^/+'), '');
    if (!s.startsWith('storage/')) {
      s = 'storage/$s';
    }
    return '$storageBaseUrl/$s';
  }

  // ------------ Outbox (SharedPreferences) ------------
  static const String _outboxKey = 'outbox_tree_monitoring_v1';
  static bool _syncListenerStarted = false;

  // Serializes outbox pushes across concurrent triggers / transient instances.
  static final Lock _outboxLock = Lock();

  // ------------ Cache keys ------------
  static String _cacheListKey(int treeId, int page, int perPage) =>
      'cache_mon_list_tree_${treeId}_p${page}_pp$perPage';
  static String _cacheListTsKey(int treeId, int page, int perPage) =>
      'cache_mon_list_tree_${treeId}_p${page}_pp${perPage}_ts';

  static String _cacheLatestKey(int treeId) => 'cache_mon_latest_tree_$treeId';
  static String _cacheLatestTsKey(int treeId) => 'cache_mon_latest_tree_${treeId}_ts';

  TreeMonitoringApi() {
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
            debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}  query=${o.queryParameters}');
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

  // ================= Helpers =================

  static String _safeJson(dynamic data) {
    if (data is FormData) {
      final fields = {for (final e in data.fields) e.key: e.value};
      final files = data.files.map((e) => {'key': e.key, 'filename': e.value.filename}).toList();
      return 'FormData(fields:${jsonEncode(fields)}, files:${jsonEncode(files)})';
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
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    });
  }

  Never _throwHttp(Response<dynamic> resp, [String msg = 'HTTP error']) {
    // DioException (with the response) so outbox push loops can classify the
    // HTTP status. The client uses `validateStatus: (_) => true`, so non-2xx
    // must be converted here or it surfaces as an unclassified plain Exception.
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: '$msg. HTTP ${resp.statusCode}: ${_safeJson(resp.data)}',
    );
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<MultipartFile?> _maybeFile(String? path, String filename) async {
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return MultipartFile.fromFile(
      path,
      filename: filename,
      contentType: _photoMediaType(path),
    );
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

  Map<String, dynamic> _stringifyBody(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) return;
      out[k] = v.toString();
    });
    return out;
  }

  // ================= Cache LIST + LATEST =================

  Future<void> _saveListCache({
    required int treeId,
    required int page,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheListKey(treeId, page, perPage), jsonEncode(data));
    await p.setInt(_cacheListTsKey(treeId, page, perPage), DateTime.now().millisecondsSinceEpoch);
  }

  Future<MonitoringPage?> _loadListCacheModel(int treeId, int page, int perPage) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheListKey(treeId, page, perPage));
    if (raw == null || raw.isEmpty) return null;
    return monitoringPageFromJson(raw);
  }

  Future<DateTime?> getListCacheTime(int treeId, {int page = 1, int perPage = 20}) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheListTsKey(treeId, page, perPage));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> _saveLatestCache({required int treeId, required dynamic data}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheLatestKey(treeId), jsonEncode(data));
    await p.setInt(_cacheLatestTsKey(treeId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<TreeMonitoring?> _loadLatestCacheModel(int treeId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheLatestKey(treeId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return TreeMonitoring.fromJson(
      Map<String, dynamic>.from(decoded is Map && decoded['data'] is Map ? decoded['data'] : decoded),
    );
  }

  Future<DateTime?> getLatestCacheTime(int treeId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheLatestTsKey(treeId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ================= API (GET) =================

  Future<MonitoringPage> listByTree({
    required int treeId,
    int page = 1,
    int perPage = 20,
  }) async {
    final opt = await _auth();
    final resp = await _dio.get(
      '/trees/$treeId/monitorings',
      options: opt,
      queryParameters: {'page': page, 'per_page': perPage},
    );
    if (resp.statusCode == 200) {
      return MonitoringPage.fromJson(Map<String, dynamic>.from(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch monitorings');
  }

  Future<MonitoringPage> listByTreeCached({
    required int treeId,
    int page = 1,
    int perPage = 20,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final res = await listByTree(treeId: treeId, page: page, perPage: perPage);
        await _saveListCache(treeId: treeId, page: page, perPage: perPage, data: res.toJson());
        return res;
      } catch (_) {
        final cached = await _loadListCacheModel(treeId, page, perPage);
        return cached ?? MonitoringPage(currentPage: page, data: const [], perPage: perPage, total: 0);
      }
    } else {
      final cached = await _loadListCacheModel(treeId, page, perPage);
      return cached ?? MonitoringPage(currentPage: page, data: const [], perPage: perPage, total: 0);
    }
  }

  Future<TreeMonitoring?> latest({required int treeId}) async {
    final opt = await _auth();
    final resp = await _dio.get('/trees/$treeId/monitorings/latest', options: opt);
    if (resp.statusCode == 200) {
      final map = (resp.data is Map) ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
      return TreeMonitoring.fromJson(map);
    }
    if (resp.statusCode == 404) return null;
    _throwHttp(resp, 'Failed to fetch latest monitoring');
  }

  Future<TreeMonitoring?> latestCached({required int treeId}) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/trees/$treeId/monitorings/latest', options: opt);
        if (resp.statusCode == 200 && resp.data != null) {
          final map = (resp.data is Map) ? Map<String, dynamic>.from(resp.data) : <String, dynamic>{};
          await _saveLatestCache(treeId: treeId, data: map);
          return TreeMonitoring.fromJson(map);
        }
        final cached = await _loadLatestCacheModel(treeId);
        if (cached != null) return cached;
        if (resp.statusCode == 404) return null;
        _throwHttp(resp, 'Failed to fetch latest monitoring');
      } catch (_) {
        final cached = await _loadLatestCacheModel(treeId);
        return cached;
      }
    } else {
      return await _loadLatestCacheModel(treeId);
    }
  }

  // ================= API (Mutasi ONLINE) =================

  Future<TreeMonitoring> createOnline({
    required int treeId,
    required DateTime measuredAt,
    String healthStatus = 'Sehat',
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoFilePath,
    String? photoBase64,
  }) async {
    Response<dynamic> resp;
    if (photoFilePath != null && photoFilePath.isNotEmpty && File(photoFilePath).existsSync()) {
      final opt = await _auth();
      final form = FormData.fromMap({
        'measured_at': measuredAt.toIso8601String(),
        'health_status': healthStatus,
        if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
        if (healthDesc != null) 'health_desc': healthDesc,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
        'photo': await MultipartFile.fromFile(photoFilePath, filename: 'monitoring.jpg', contentType: _photoMediaType(photoFilePath)),
      });
      resp = await _dio.post('/trees/$treeId/monitorings', data: form, options: opt);
    } else {
      final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
      final body = {
        'measured_at': measuredAt.toIso8601String(),
        'health_status': healthStatus,
        if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
        if (healthDesc != null) 'health_desc': healthDesc,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
        if (photoBase64 != null) 'photo_base64': photoBase64,
      };
      resp = await _dio.post('/trees/$treeId/monitorings', data: jsonEncode(body), options: opt);
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = (resp.data is Map && resp.data['data'] is Map) ? resp.data['data'] : resp.data;
      return TreeMonitoring.fromJson(Map<String, dynamic>.from(data));
    }
    _throwHttp(resp, 'Failed to create monitoring');
  }

  Future<TreeMonitoring> updateOnline({
    required int monitoringId,
    DateTime? measuredAt,
    String? healthStatus,
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoFilePath,
    String? photoBase64,
  }) async {
    Response<dynamic> resp;
    if (photoFilePath != null && photoFilePath.isNotEmpty && File(photoFilePath).existsSync()) {
      final opt = await _auth();
      final form = FormData.fromMap({
        if (measuredAt != null) 'measured_at': measuredAt.toIso8601String(),
        if (healthStatus != null) 'health_status': healthStatus,
        if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
        if (healthDesc != null) 'health_desc': healthDesc,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
        'photo': await MultipartFile.fromFile(photoFilePath, filename: 'monitoring.jpg', contentType: _photoMediaType(photoFilePath)),
      });
      resp = await _dio.post(
        '/tree-monitorings/$monitoringId',
        data: form..fields.add(const MapEntry('_method', 'PUT')),
        options: opt,
      );
    } else {
      final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});
      final body = {
        if (measuredAt != null) 'measured_at': measuredAt.toIso8601String(),
        if (healthStatus != null) 'health_status': healthStatus,
        if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
        if (healthDesc != null) 'health_desc': healthDesc,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
        if (photoBase64 != null) 'photo_base64': photoBase64,
        '_method': 'PUT',
      };
      resp = await _dio.post('/tree-monitorings/$monitoringId', data: jsonEncode(body), options: opt);
    }

    if (resp.statusCode == 200) {
      final data = (resp.data is Map && resp.data['data'] is Map) ? resp.data['data'] : resp.data;
      return TreeMonitoring.fromJson(Map<String, dynamic>.from(data));
    }
    _throwHttp(resp, 'Failed to update monitoring');
  }

  Future<String> deleteOnline(int monitoringId) async {
    final opt = await _auth();
    final resp = await _dio.delete('/tree-monitorings/$monitoringId', options: opt);
    if (resp.statusCode == 200) {
      return resp.data['message']?.toString() ?? 'Monitoring dihapus';
    }
    _throwHttp(resp, 'Failed to delete monitoring');
  }

  // ================= OFFLINE-FIRST =================

  Future<TreeMonitoringOpResult> createOfflineFirst({
    required int treeId,
    DateTime? measuredAt, // required by server → default now
    String healthStatus = 'Sehat',
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoPath, // local file path (persisten)
  }) async {
    final online = await _isOnline();
    final when = measuredAt ?? DateTime.now();

    if (online) {
      await createOnline(
        treeId: treeId,
        measuredAt: when,
        healthStatus: healthStatus,
        circumferenceCm: circumferenceCm,
        healthDesc: healthDesc,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        recordedByKthId: recordedByKthId,
        photoFilePath: photoPath,
      );
      final pushed = await pushOutbox();
      final count = await getOutboxCount();
      return TreeMonitoringOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Monitoring ditambahkan.',
      );
    }

    final list = await _loadOutbox();
    final body = _stringifyBody({
      'measured_at': when.toIso8601String(),
      'health_status': healthStatus,
      if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
      if (healthDesc != null) 'health_desc': healthDesc,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
      if (photoPath != null) 'photo_path': photoPath,
    });

    list.add(_MonOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST',
      endpoint: '/trees/$treeId/monitorings',
      body: body,
      entityId: null,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    await _saveOutbox(list);

    return TreeMonitoringOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: list.length,
      message: 'Monitoring disimpan offline. Akan diunggah saat online.',
    );
  }

  Future<TreeMonitoringOpResult> updateOfflineFirst({
    required int monitoringId,
    DateTime? measuredAt,
    String? healthStatus,
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoPath,
  }) async {
    final online = await _isOnline();

    if (online) {
      await updateOnline(
        monitoringId: monitoringId,
        measuredAt: measuredAt,
        healthStatus: healthStatus,
        circumferenceCm: circumferenceCm,
        healthDesc: healthDesc,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        recordedByKthId: recordedByKthId,
        photoFilePath: photoPath,
      );
      final pushed = await pushOutbox();
      final count = await getOutboxCount();
      return TreeMonitoringOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Monitoring diperbarui.',
      );
    }

    final list = await _loadOutbox();
    final body = _stringifyBody({
      if (measuredAt != null) 'measured_at': measuredAt.toIso8601String(),
      if (healthStatus != null) 'health_status': healthStatus,
      if (circumferenceCm != null) 'circumference_cm': circumferenceCm,
      if (healthDesc != null) 'health_desc': healthDesc,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (recordedByKthId != null) 'recorded_by_kth_id': recordedByKthId,
      if (photoPath != null) 'photo_path': photoPath,
    });

    list.add(_MonOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'PUT',
      endpoint: '/tree-monitorings/$monitoringId',
      body: body,
      entityId: monitoringId,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return TreeMonitoringOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan monitoring disimpan offline. Akan diunggah saat online.',
    );
  }

  Future<TreeMonitoringOpResult> deleteOfflineFirst(int monitoringId) async {
    final online = await _isOnline();

    if (online) {
      await deleteOnline(monitoringId);
      final pushed = await pushOutbox();
      final count = await getOutboxCount();
      return TreeMonitoringOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Monitoring dihapus.',
      );
    }

    final list = await _loadOutbox();
    list.add(_MonOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'DELETE',
      endpoint: '/tree-monitorings/$monitoringId',
      body: const {},
      entityId: monitoringId,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return TreeMonitoringOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan monitoring disimpan offline. Akan diunggah saat online.',
    );
  }

  // ====== Alias supaya cocok dengan pemanggilan di UI ======
  Future<TreeMonitoringOpResult> addMonitoringOfflineFirst({
    required int treeId,
    DateTime? measuredAt,
    String healthStatus = 'Sehat',
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoPath,
  }) {
    return createOfflineFirst(
      treeId: treeId,
      measuredAt: measuredAt,
      healthStatus: healthStatus,
      circumferenceCm: circumferenceCm,
      healthDesc: healthDesc,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      recordedByKthId: recordedByKthId,
      photoPath: photoPath,
    );
  }

  Future<TreeMonitoringOpResult> editMonitoringOfflineFirst({
    required int monitoringId,
    DateTime? measuredAt,
    String? healthStatus,
    double? circumferenceCm,
    String? healthDesc,
    double? latitude,
    double? longitude,
    double? accuracyM,
    int? recordedByKthId,
    String? photoPath,
  }) {
    return updateOfflineFirst(
      monitoringId: monitoringId,
      measuredAt: measuredAt,
      healthStatus: healthStatus,
      circumferenceCm: circumferenceCm,
      healthDesc: healthDesc,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      recordedByKthId: recordedByKthId,
      photoPath: photoPath,
    );
  }

  // ================= PUSH Outbox =================

  Future<List<_MonOutboxItem>> _loadOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_outboxKey) ?? <String>[];
    final list = raw.map((s) => _MonOutboxItem.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }

  Future<void> _saveOutbox(List<_MonOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_outboxKey, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  List<_MonOutboxItem> _dedupeByEntityId(List<_MonOutboxItem> l) {
    final map = <int, _MonOutboxItem>{};
    final others = <_MonOutboxItem>[];
    for (final it in l) {
      if (it.entityId == null) {
        others.add(it);
      } else {
        final id = it.entityId!;
        final prev = map[id];
        if (prev == null || it.ts >= prev.ts) map[id] = it;
      }
    }
    final vals = map.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final all = <_MonOutboxItem>[...others, ...vals]..sort((a, b) => a.ts.compareTo(b.ts));
    return all;
  }

  Future<int> getOutboxCount() async => (await _loadOutbox()).length;

  /// Queued monitoring ops for one tree, ready for the list screen. A queued
  /// create carries its tree in the endpoint (`/trees/{id}/monitorings`), not
  /// in the body, so that is what scopes the creates here.
  static Future<PendingIndex> pendingIndex({required int treeId}) async {
    final idx = PendingIndex.from(await PendingOps.read(_outboxKey));
    return idx.whereCreate(
      (op) => op.endpoint == '/trees/$treeId/monitorings',
    );
  }

  /// Renders a queued create as a list row — same snake_case fields as the
  /// server response, with a synthetic negative id marking it as local.
  static TreeMonitoring pendingMonitoringRow(
    PendingOp op, {
    required int treeId,
  }) => TreeMonitoring.fromJson({
    ...op.body,
    'id': op.localId,
    'tree_id': treeId,
    'created_at': op.queuedAt.toIso8601String(),
    'updated_at': op.queuedAt.toIso8601String(),
  });

  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushOutbox() => _outboxLock.synchronized(_pushOutboxLocked);

  Future<int> _pushOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadOutbox();
    if (list.isEmpty) return 0;

    int success = 0;
    for (final item in List<_MonOutboxItem>.from(list)) {
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

  Future<void> _pushItemOnline(_MonOutboxItem it) async {
    if (it.method == 'POST' && it.endpoint.startsWith('/trees/')) {
      final opt = await _auth();
      final form = await _buildFormData(it.body);
      final resp = await _dio.post(it.endpoint, data: form, options: opt);
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      _throwHttp(resp, 'Failed to create monitoring (push)');
    } else if (it.method == 'PUT' && it.endpoint.startsWith('/tree-monitorings/')) {
      final opt = await _auth();
      final form = await _buildFormData(it.body);
      if (!form.fields.any((e) => e.key == '_method')) {
        form.fields.add(const MapEntry('_method', 'PUT'));
      }
      final resp = await _dio.post(it.endpoint, data: form, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update monitoring (push)');
    } else if (it.method == 'DELETE' && it.endpoint.startsWith('/tree-monitorings/')) {
      final opt = await _auth();
      final resp = await _dio.delete(it.endpoint, options: opt);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete monitoring (push)');
    } else {
      throw Exception('Unsupported outbox item: ${it.method} ${it.endpoint}');
    }
  }

  Future<FormData> _buildFormData(Map<String, dynamic> body) async {
    final form = FormData();

    // scalar
    for (final k in const [
      'measured_at','circumference_cm','health_status','health_desc',
      'latitude','longitude','accuracy_m','recorded_by_kth_id','_method'
    ]) {
      final v = body[k];
      if (v != null && v.toString().isNotEmpty) {
        form.fields.add(MapEntry(k, v.toString()));
      }
    }

    // photo
    final photo = await _maybeFile(body['photo_path']?.toString(), 'monitoring.jpg');
    if (photo != null) {
      form.files.add(MapEntry('photo', photo));
    }

    return form;
  }

  // ================= Auto Sync Listener =================

  static Future<void> startAutoSyncListener() async {
    if (_syncListenerStarted) return;
    _syncListenerStarted = true;

    Future<void> flush() async {
      try {
        await TreeMonitoringApi().pushOutbox();
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (pushOutbox self-guards on connectivity).
    await flush();
  }
}
