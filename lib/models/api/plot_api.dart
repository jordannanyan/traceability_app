// lib/models/api/plot_api.dart
//
// DROP-IN REPLACEMENT (Plot + Polygon Points + Photo Upload, offline-first)
//
// ✅ Tetap kompatibel dengan fitur lama:
// - GET cached-first (kth/farmer)
// - add/edit/delete offline-first (outbox)
// - add/edit support polygon WKT string
//
// ✅ Tambahan untuk KthPolygonScreen:
// - GET /plots/{id}/polygon-points
// - PUT /plots/{id}/polygon-points (replace points)
// - POST /plots/{id}/polygon-points/{seq}/photo (multipart upload)
// - Semua ada versi offline-first (queue), lalu auto-push saat online
//
// Catatan:
// - Untuk endpoint PUT polygon-points, backend kamu sudah menerima JSON.
// - Untuk upload foto, backend menerima multipart field 'photo'.
// - Outbox disimpan di SharedPreferences sebagai StringList JSON.

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/add_plot.dart';
import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/edit_plot.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart';
// Both plot list models declare `Datum`; the prefix disambiguates the one the
// pending-row builder returns.
import 'package:traceability_app/models/get_plot_by_farmer_id.dart'
    as farmer_plot;
import 'package:traceability_app/models/get_plot_by_id.dart';
import 'package:traceability_app/models/get_plot_by_kth_id.dart';
import 'package:traceability_app/utils/utils.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

/// Hasil operasi offline-first (add/edit/delete/polygon-points/photo)
class PlotOpResult {
  final bool appliedOnline; // sukses langsung ke server
  final bool queued; // masuk outbox
  final int outboxCount; // jumlah task outbox saat ini
  final String message; // pesan untuk UI

  const PlotOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Model data polygon-point untuk kebutuhan layar polygon (tanpa UI class private)
class PlotPolygonPoint {
  final int seq; // urutan 1..n
  final double latitude;
  final double longitude;
  final DateTime? capturedAt;
  final double? accuracyM;
  final String? source;
  final String? remotePhotoPath;

  const PlotPolygonPoint({
    required this.seq,
    required this.latitude,
    required this.longitude,
    this.capturedAt,
    this.accuracyM,
    this.source,
    this.remotePhotoPath,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'latitude': latitude,
        'longitude': longitude,
        'captured_at': (capturedAt ?? DateTime.now()).toIso8601String(),
        'accuracy_m': accuracyM,
        'source': source ?? 'mobile',
      };
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s);
  }
  static PlotPolygonPoint? fromMap(dynamic item) {
    if (item is! Map) return null;
    final seq = _toInt(item['seq']) ?? 0;
    final lat = _toDouble(item['latitude']);
    final lng = _toDouble(item['longitude']);
    if (seq <= 0 || lat == null || lng == null) return null;

    return PlotPolygonPoint(
      seq: seq,
      latitude: lat,
      longitude: lng,
      capturedAt: DateTime.tryParse((item['captured_at'] ?? '').toString()),
      accuracyM: _toDouble(item['accuracy_m']),
      source: (item['source'] ?? '').toString().trim().isEmpty ? null : item['source'].toString(),
      remotePhotoPath: (item['photo_path'] ?? '').toString().trim().isEmpty ? null : item['photo_path'].toString(),
    );
  }
}

// ====================== Outbox internal ======================

/// Outbox item untuk operasi plot + polygon-points + upload photo
class _PlotOutboxItem {
  final String id; // unik, pakai epoch millis string
  final String kind; // 'plot' | 'polygon_points' | 'polygon_photo'
  final String method; // 'POST' | 'PUT' | 'DELETE'
  final String endpoint; // contoh '/plots', '/plots/{id}/polygon-points', dst.
  final Map<String, dynamic> body; // payload JSON, atau metadata (foto)
  final int? entityId; // plotId (untuk dedupe)
  final String? entityKey; // untuk dedupe yang lebih spesifik, contoh 'plot:12:seq:3'
  final int ts; // timestamp millis

  _PlotOutboxItem({
    required this.id,
    required this.kind,
    required this.method,
    required this.endpoint,
    required this.body,
    required this.entityId,
    required this.entityKey,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'entity_id': entityId,
        'entity_key': entityKey,
        'ts': ts,
      };

  factory _PlotOutboxItem.fromJson(Map<String, dynamic> j) => _PlotOutboxItem(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'plot') as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int?,
        entityKey: j['entity_key'] as String?,
        ts: j['ts'] as int,
      );
}

class PlotApi {
  late final Dio _dio;

  // ========= Outbox =========
  static const String _outboxKey = 'outbox_plot_v2'; // v2 (plot + polygon points + photo)
  static const String _legacyOutboxKey = 'outbox_plot_v1'; // migrasi dari versi lama bila ada
  static bool _syncListenerStarted = false;

  // Serializes outbox pushes so concurrent triggers (reconnect listener,
  // SyncService, _tryPushSoon, manual Sync button) can't run in parallel and
  // double-send / clobber the same SharedPreferences outbox. Static = shared
  // across the many transient PlotApi() instances.
  static final Lock _outboxLock = Lock();

  // ========= Cache keys =========
  static String _cacheFarmerKey(int farmerId) => 'cache_plot_by_farmer_$farmerId';
  static String _cacheFarmerTsKey(int farmerId) => 'cache_plot_by_farmer_${farmerId}_ts';

  static String _cacheKthKey(int kthId) => 'cache_plot_by_kth_$kthId';
  static String _cacheKthTsKey(int kthId) => 'cache_plot_by_kth_${kthId}_ts';

  PlotApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
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

  // ================= Helpers umum =================

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
    // Throw a DioException carrying the response so outbox push loops can
    // classify the HTTP status (poison vs retry). Because the client uses
    // `validateStatus: (_) => true`, a non-2xx never raises a DioException on
    // its own — without this it would surface as a plain Exception and get
    // mis-handled as an unclassified failure that blocks the queue.
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: '$fallback (HTTP ${resp.statusCode}): ${_safeJson(resp.data)}',
    );
  }

  /// Tentukan MIME type dari ekstensi file. Wajib di-set eksplisit karena
  /// pada device fisik Android, auto-detect Dio sering gagal → server
  /// Laravel menolak dengan "The photo failed to upload."
  static DioMediaType _photoMediaType(String path) {
    final lp = path.toLowerCase();
    if (lp.endsWith('.png')) return DioMediaType('image', 'png');
    if (lp.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lp.endsWith('.heic') || lp.endsWith('.heif')) {
      return DioMediaType('image', 'heic');
    }
    return DioMediaType('image', 'jpeg'); // default jpg
  }

  /// Robust connectivity untuk berbagai versi connectivity_plus
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  static String? _normPoly(String? polygonWkt) {
    final s = polygonWkt?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ================= Outbox helpers =================

  Future<void> _migrateLegacyOutboxIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasV2 = prefs.getStringList(_outboxKey) != null;
    if (hasV2) return;

    final legacy = prefs.getStringList(_legacyOutboxKey);
    if (legacy == null || legacy.isEmpty) {
      // create empty v2 outbox so migration won't repeat
      await prefs.setStringList(_outboxKey, <String>[]);
      return;
    }

    // Legacy item format: {id, method, endpoint, body, entity_id, ts}
    // Convert into v2 with kind='plot' and entityKey null.
    final converted = <String>[];
    for (final s in legacy) {
      try {
        final j = jsonDecode(s);
        if (j is! Map) continue;
        final m = Map<String, dynamic>.from(j);
        final v2 = _PlotOutboxItem(
          id: (m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
          kind: 'plot',
          method: (m['method'] ?? 'POST').toString(),
          endpoint: (m['endpoint'] ?? '/plots').toString(),
          body: (m['body'] is Map) ? Map<String, dynamic>.from(m['body']) : <String, dynamic>{},
          entityId: _toInt(m['entity_id']),
          entityKey: null,
          ts: _toInt(m['ts']) ?? DateTime.now().millisecondsSinceEpoch,
        );
        converted.add(jsonEncode(v2.toJson()));
      } catch (_) {
        // skip
      }
    }

    await prefs.setStringList(_outboxKey, converted);
    // optional: keep legacy for safety, but to avoid double processing we can clear it
    await prefs.remove(_legacyOutboxKey);
  }

  Future<List<_PlotOutboxItem>> _loadOutbox() async {
    await _migrateLegacyOutboxIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_outboxKey) ?? <String>[];
    final list = raw.map((s) => _PlotOutboxItem.fromJson(jsonDecode(s))).toList();
    list.sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }

  Future<void> _saveOutbox(List<_PlotOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _outboxKey,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Dedupe:
  /// - Jika entityKey ada, sisakan terbaru per entityKey (paling spesifik, untuk foto dan polygon_points)
  /// - Else jika entityId ada, sisakan terbaru per entityId (untuk edit/delete plot)
  /// - Create plot (entityId null) tidak didedupe
  List<_PlotOutboxItem> _dedupe(List<_PlotOutboxItem> l) {
    final keyMap = <String, _PlotOutboxItem>{};
    final idMap = <int, _PlotOutboxItem>{};
    final others = <_PlotOutboxItem>[];

    for (final it in l) {
      final k = it.entityKey;
      if (k != null && k.trim().isNotEmpty) {
        final prev = keyMap[k];
        if (prev == null || it.ts >= prev.ts) keyMap[k] = it;
        continue;
      }

      if (it.entityId == null) {
        others.add(it);
      } else {
        final id = it.entityId!;
        final prev = idMap[id];
        if (prev == null || it.ts >= prev.ts) idMap[id] = it;
      }
    }

    final vals1 = keyMap.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final vals2 = idMap.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));

    final all = <_PlotOutboxItem>[...others, ...vals2, ...vals1]..sort((a, b) => a.ts.compareTo(b.ts));
    return all;
  }

  Future<int> getPlotOutboxCount() async {
    final l = await _loadOutbox();
    return l.length;
  }

  /// Queued plot ops for one farmer, ready for the list screen.
  ///
  /// The plot outbox also carries polygon-point and photo items; those always
  /// belong to an existing plot, so they surface as a pending *change* on that
  /// plot's row rather than as rows of their own.
  static Future<PendingIndex> pendingIndex({required int farmerId}) async {
    final idx = PendingIndex.from(await PendingOps.read(_outboxKey));
    return idx.whereCreate(
      (op) => pendingBodyInt(op.body, 'farmer_id') == farmerId,
    );
  }

  /// Renders a queued plot create as a list row, with a synthetic negative id.
  static farmer_plot.Datum pendingPlotRow(PendingOp op) =>
      farmer_plot.Datum.fromJson({
    ...op.body,
    'id': op.localId,
    'created_at': op.queuedAt.toIso8601String(),
    'updated_at': op.queuedAt.toIso8601String(),
  });

  // ================= Cache helpers =================

  Future<void> _saveFarmerCache({required int farmerId, required dynamic data}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheFarmerKey(farmerId), jsonEncode(data));
    await p.setInt(_cacheFarmerTsKey(farmerId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetPlotByFarmerId?> _loadFarmerCacheModel(int farmerId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheFarmerKey(farmerId));
    if (raw == null || raw.isEmpty) return null;
    return getPlotByFarmerIdFromJson(raw);
  }

  Future<DateTime?> getPlotByFarmerCacheTime(int farmerId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheFarmerTsKey(farmerId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> _saveKthCache({required int kthId, required dynamic data}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKthKey(kthId), jsonEncode(data));
    await p.setInt(_cacheKthTsKey(kthId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetPlotByKthId?> _loadKthCacheModel(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKthKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    return getPlotByKthIdFromJson(raw);
  }

  Future<DateTime?> getPlotByKthCacheTime(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheKthTsKey(kthId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ================= API (GET) =================

  /// Versi online murni (dipertahankan)
  Future<GetPlotByKthId> getPlotByKthId(int kthId) async {
    final opt = await _auth();
    final resp = await _dio.get('/plots/kth/$kthId', options: opt);
    if (resp.statusCode == 200) {
      return getPlotByKthIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch plot data by KTH');
  }

  /// Versi cached-first (offline-first)
  Future<CachedResult<GetPlotByKthId>> getPlotByKthIdCached(int kthId) =>
      readCachedFirst<GetPlotByKthId>(
        isOnline: _isOnline,
        request: () async =>
            _dio.get('/plots/kth/$kthId', options: await _auth()),
        parseAndCache: (resp) async {
          await _saveKthCache(kthId: kthId, data: resp.data);
          return getPlotByKthIdFromJson(jsonEncode(resp.data));
        },
        readCache: () => _loadKthCacheModel(kthId),
        emptyValue: (outcome) => GetPlotByKthId(
          status: outcome == RefreshOutcome.offlineCache
              ? 'offline-no-cache'
              : 'online-error-no-cache',
          data: [],
        ),
      );

  /// Versi online murni (dipertahankan)
  Future<GetPlotByFarmerId> getPlotByFarmerId(int farmerId) async {
    final opt = await _auth();
    final resp = await _dio.get('/plots/farmer/$farmerId', options: opt);
    if (resp.statusCode == 200) {
      return getPlotByFarmerIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch plot data by farmer');
  }

  /// Versi cached-first (offline-first)
  Future<CachedResult<GetPlotByFarmerId>> getPlotByFarmerIdCached(
    int farmerId,
  ) => readCachedFirst<GetPlotByFarmerId>(
    isOnline: _isOnline,
    request: () async =>
        _dio.get('/plots/farmer/$farmerId', options: await _auth()),
    parseAndCache: (resp) async {
      await _saveFarmerCache(farmerId: farmerId, data: resp.data);
      return getPlotByFarmerIdFromJson(jsonEncode(resp.data));
    },
    readCache: () => _loadFarmerCacheModel(farmerId),
    emptyValue: (outcome) => GetPlotByFarmerId(
      status: outcome == RefreshOutcome.offlineCache
          ? 'offline-no-cache'
          : 'online-error-no-cache',
      data: [],
    ),
  );

  /// Detail plot
  Future<GetPlotById> getPlotById(int plotId) async {
    final opt = await _auth();
    final resp = await _dio.get('/plots/$plotId', options: opt);
    if (resp.statusCode == 200) {
      return getPlotByIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch plot by ID');
  }

  // ================= API (Mutasi ONLINE murni) =================

  Future<AddPlot> addPlot({
    required String plotName,
    required dynamic landArea,
    required int numberOfPlants,
    required double latitude,
    required double longitude,
    required int farmerId,
    String? polygon, // WKT string
  }) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});

    final payload = <String, dynamic>{
      "plot_name": plotName,
      "land_area": landArea,
      "number_of_plants": numberOfPlants,
      "latitude": latitude,
      "longitude": longitude,
      "farmer_id": farmerId,
      if (_normPoly(polygon) != null) "polygon": _normPoly(polygon),
    };

    final resp = await _dio.post(
      '/plots',
      options: opt,
      data: jsonEncode(payload),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return addPlotFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to add plot');
  }

  Future<EditPlot> editPlot({
    required int id,
    required String plotName,
    required dynamic landArea,
    required int numberOfPlants,
    required double latitude,
    required double longitude,
    required int farmerId,
    String? polygon, // WKT string
  }) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});

    // method spoofing (_method=PUT) via POST (sesuai backend kamu)
    final payload = <String, dynamic>{
      "_method": "PUT",
      "plot_name": plotName,
      "land_area": landArea,
      "number_of_plants": numberOfPlants,
      "latitude": latitude,
      "longitude": longitude,
      "farmer_id": farmerId,
      if (_normPoly(polygon) != null) "polygon": _normPoly(polygon),
    };

    final resp = await _dio.post(
      '/plots/$id',
      options: opt,
      data: jsonEncode(payload),
    );

    if (resp.statusCode == 200) {
      return editPlotFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to update plot');
  }

  Future<String> deletePlot(int plotId) async {
    final opt = await _auth();
    final resp = await _dio.delete('/plots/$plotId', options: opt);
    if (resp.statusCode == 200) {
      return resp.data['message']?.toString() ?? 'Plot deleted successfully';
    }
    _throwHttp(resp, 'Failed to delete plot');
  }

  // ================= Polygon Points (ONLINE) =================

  /// GET /plots/{plotId}/polygon-points
  Future<List<PlotPolygonPoint>> getPolygonPoints(int plotId) async {
    final opt = await _auth();
    final resp = await _dio.get('/plots/$plotId/polygon-points', options: opt);

    if (resp.statusCode == 200) {
      final body = resp.data;
      final list = (body is Map ? (body['data'] ?? []) : []) as List<dynamic>;
      final out = <PlotPolygonPoint>[];
      for (final it in list) {
        final p = PlotPolygonPoint.fromMap(it);
        if (p != null) out.add(p);
      }
      out.sort((a, b) => a.seq.compareTo(b.seq));
      return out;
    }

    _throwHttp(resp, 'Failed to fetch polygon points');
  }

  /// PUT /plots/{plotId}/polygon-points (replace all points)
  Future<void> replacePolygonPoints({
    required int plotId,
    required List<PlotPolygonPoint> points,
  }) async {
    final opt = await _auth(extraHeaders: {'Content-Type': 'application/json'});

    final payload = <String, dynamic>{
      'points': points
          .map((p) => {
                'seq': p.seq,
                'latitude': p.latitude,
                'longitude': p.longitude,
                'captured_at': (p.capturedAt ?? DateTime.now()).toIso8601String(),
                'accuracy_m': p.accuracyM,
                'source': p.source ?? 'mobile',
              })
          .toList(),
    };

    final resp = await _dio.put(
      '/plots/$plotId/polygon-points',
      options: opt,
      data: jsonEncode(payload),
    );

    if (resp.statusCode == 200) return;
    _throwHttp(resp, 'Failed to replace polygon points');
  }

  /// POST /plots/{plotId}/polygon-points/{seq}/photo (multipart)
  Future<void> uploadPolygonPointPhoto({
    required int plotId,
    required int seq,
    required String filePath,
  }) async {
    final f = File(filePath);
    if (!await f.exists()) throw Exception('Photo file not found: $filePath');

    final opt = await _auth();
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        f.path,
        filename: 'poly_${plotId}_$seq.jpg',
        contentType: _photoMediaType(f.path),
      ),
    });

    final resp = await _dio.post(
      '/plots/$plotId/polygon-points/$seq/photo',
      options: opt.copyWith(contentType: 'multipart/form-data'),
      data: form,
    );

    if (resp.statusCode == 200) return;
    _throwHttp(resp, 'Failed to upload polygon point photo');
  }

  // ================= API (Mutasi OFFLINE-FIRST) =================

  /// Tambah plot offline-first. Saat offline -> simpan ke outbox.
  Future<PlotOpResult> addPlotOfflineFirst({
    required String plotName,
    required dynamic landArea,
    required int numberOfPlants,
    required double latitude,
    required double longitude,
    required int farmerId,
    String? polygon,
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await addPlot(
          plotName: plotName,
          landArea: landArea,
          numberOfPlants: numberOfPlants,
          latitude: latitude,
          longitude: longitude,
          farmerId: farmerId,
          polygon: polygon,
        );
        final pushed = await pushPlotOutbox();
        final count = await getPlotOutboxCount();
        return PlotOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Plot ditambahkan.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('addPlot online failed, queueing offline: $e');
        }
      }
    }

    // OFFLINE -> queue POST /plots
    final list = await _loadOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    final body = <String, dynamic>{
      "plot_name": plotName,
      "land_area": landArea,
      "number_of_plants": numberOfPlants,
      "latitude": latitude,
      "longitude": longitude,
      "farmer_id": farmerId,
      if (_normPoly(polygon) != null) "polygon": _normPoly(polygon),
    };

    list.add(
      _PlotOutboxItem(
        id: now.toString(),
        kind: 'plot',
        method: 'POST',
        endpoint: '/plots',
        body: body,
        entityId: null, // create belum punya id server
        entityKey: null,
        ts: now,
      ),
    );

    await _saveOutbox(list);

    _tryPushSoon();

    return PlotOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: list.length,
      message: 'Tersimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Edit plot offline-first
  Future<PlotOpResult> editPlotOfflineFirst({
    required int id,
    required String plotName,
    required dynamic landArea,
    required int numberOfPlants,
    required double latitude,
    required double longitude,
    required int farmerId,
    String? polygon,
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await editPlot(
          id: id,
          plotName: plotName,
          landArea: landArea,
          numberOfPlants: numberOfPlants,
          latitude: latitude,
          longitude: longitude,
          farmerId: farmerId,
          polygon: polygon,
        );
        final pushed = await pushPlotOutbox();
        final count = await getPlotOutboxCount();
        return PlotOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Plot diperbarui.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('editPlot online failed, queueing offline: $e');
        }
      }
    }

    // OFFLINE -> queue POST /plots/{id} + _method=PUT
    final list = await _loadOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    final body = <String, dynamic>{
      "_method": "PUT",
      "plot_name": plotName,
      "land_area": landArea,
      "number_of_plants": numberOfPlants,
      "latitude": latitude,
      "longitude": longitude,
      "farmer_id": farmerId,
      if (_normPoly(polygon) != null) "polygon": _normPoly(polygon),
    };

    list.add(
      _PlotOutboxItem(
        id: now.toString(),
        kind: 'plot',
        method: 'POST',
        endpoint: '/plots/$id',
        body: body,
        entityId: id,
        entityKey: 'plot:$id', // dedupe via entityKey
        ts: now,
      ),
    );

    final deduped = _dedupe(list);
    await _saveOutbox(deduped);

    _tryPushSoon();

    return PlotOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Hapus plot offline-first
  Future<PlotOpResult> deletePlotOfflineFirst(int plotId) async {
    final online = await _isOnline();

    if (online) {
      try {
        await deletePlot(plotId);
        final pushed = await pushPlotOutbox();
        final count = await getPlotOutboxCount();
        return PlotOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Plot dihapus.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('deletePlot online failed, queueing offline: $e');
        }
      }
    }

    // OFFLINE -> queue DELETE /plots/{id}
    final list = await _loadOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    list.add(
      _PlotOutboxItem(
        id: now.toString(),
        kind: 'plot',
        method: 'DELETE',
        endpoint: '/plots/$plotId',
        body: const {},
        entityId: plotId,
        entityKey: 'plot:$plotId', // dedupe via entityKey
        ts: now,
      ),
    );

    final deduped = _dedupe(list);
    await _saveOutbox(deduped);

    _tryPushSoon();

    return PlotOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  // ================= Polygon Points (OFFLINE-FIRST) =================

  /// Replace polygon points offline-first.
  /// - online: PUT langsung, lalu push outbox lain
  /// - offline: queue PUT /plots/{plotId}/polygon-points (dedupe per plotId)
  Future<PlotOpResult> replacePolygonPointsOfflineFirst({
    required int plotId,
    required List<PlotPolygonPoint> points,
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await replacePolygonPoints(plotId: plotId, points: points);
        final pushed = await pushPlotOutbox();
        final count = await getPlotOutboxCount();
        return PlotOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Polygon tersimpan.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('replacePolygonPoints online failed, queueing offline: $e');
        }
      }
    }

    final list = await _loadOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    final payload = <String, dynamic>{
      'points': points.map((p) => p.toJson()).toList(),
    };

    list.add(
      _PlotOutboxItem(
        id: now.toString(),
        kind: 'polygon_points',
        method: 'PUT',
        endpoint: '/plots/$plotId/polygon-points',
        body: payload,
        entityId: plotId,
        entityKey: 'polygon_points:plot:$plotId', // dedupe per plot
        ts: now,
      ),
    );

    final deduped = _dedupe(list);
    await _saveOutbox(deduped);

    _tryPushSoon();

    return PlotOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Polygon disimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Upload photo offline-first.
  /// - online: upload langsung
  /// - offline: queue upload (dedupe per plotId+seq, simpan filePath)
  Future<PlotOpResult> uploadPolygonPointPhotoOfflineFirst({
    required int plotId,
    required int seq,
    required String filePath,
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await uploadPolygonPointPhoto(plotId: plotId, seq: seq, filePath: filePath);
        final pushed = await pushPlotOutbox();
        final count = await getPlotOutboxCount();
        return PlotOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Foto tersimpan.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('uploadPolygonPointPhoto online failed, queueing offline: $e');
        }
      }
    }

    final list = await _loadOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    list.add(
      _PlotOutboxItem(
        id: now.toString(),
        kind: 'polygon_photo',
        method: 'POST',
        endpoint: '/plots/$plotId/polygon-points/$seq/photo',
        body: {
          'file_path': filePath,
          'plot_id': plotId,
          'seq': seq,
        },
        entityId: plotId,
        entityKey: 'polygon_photo:plot:$plotId:seq:$seq', // dedupe per point
        ts: now,
      ),
    );

    final deduped = _dedupe(list);
    await _saveOutbox(deduped);

    _tryPushSoon();

    return PlotOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Foto disimpan offline. Akan diunggah saat online.',
    );
  }

  /// Coba push outbox setelah delay singkat. Non-blocking — jalan di
  /// background, tidak menunda return ke caller. Aman dipanggil berkali-kali
  /// karena pushPlotOutbox sudah cek _isOnline di awal.
  void _tryPushSoon() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final pushed = await pushPlotOutbox();
        if (pushed > 0) {
          final remaining = await getPlotOutboxCount();
          if (remaining > 0) {
            if (kDebugMode) {
              debugPrint('🔄 plot outbox: pushed $pushed, remaining $remaining — retrying');
            }
            _tryPushSoon();
          }
        }
      } catch (_) {}
    });
  }

  // ================= Outbox push =================

  /// Dorong semua outbox saat online. Return jumlah task yang sukses.
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushPlotOutbox() =>
      _outboxLock.synchronized(_pushPlotOutboxLocked);

  Future<int> _pushPlotOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadOutbox();
    if (list.isEmpty) return 0;

    int success = 0;

    for (final item in List<_PlotOutboxItem>.from(list)) {
      try {
        await _pushItemOnline(item);
        success++;
        list.removeWhere((e) => e.id == item.id);
        await _saveOutbox(list);
      } catch (e) {
        // Poison (invalid 4xx) → drop and keep processing the rest so one bad
        // item never blocks the whole queue. Otherwise (network/5xx/auth/
        // timeout/local error) → stop and retry the whole batch later.
        if (isPoisonOutboxError(e)) {
          if (kDebugMode) {
            debugPrint(
              'plot outbox poison item ${item.method} ${item.endpoint}, dropping: $e',
            );
          }
          list.removeWhere((x) => x.id == item.id);
          await _saveOutbox(list);
          continue;
        }
        break;
      }
    }
    return success;
  }

  Future<void> _pushItemOnline(_PlotOutboxItem it) async {
    // JSON auth for PUT/POST json
    final optJson = await _auth(extraHeaders: {'Content-Type': 'application/json'});

    // ========= PLOT =========
    if (it.kind == 'plot') {
      if (it.method == 'POST' && it.endpoint == '/plots') {
        final resp = await _dio.post(it.endpoint, options: optJson, data: jsonEncode(it.body));
        if (resp.statusCode == 200 || resp.statusCode == 201) return;
        _throwHttp(resp, 'Failed to add plot (push)');
      }

      if (it.method == 'POST' && it.endpoint.startsWith('/plots/')) {
        final resp = await _dio.post(it.endpoint, options: optJson, data: jsonEncode(it.body));
        if (resp.statusCode == 200) return;
        _throwHttp(resp, 'Failed to update plot (push)');
      }

      if (it.method == 'DELETE' && it.endpoint.startsWith('/plots/')) {
        final opt = await _auth();
        final resp = await _dio.delete(it.endpoint, options: opt);
        if (resp.statusCode == 200) return;
        _throwHttp(resp, 'Failed to delete plot (push)');
      }

      throw Exception('Unsupported plot outbox item: ${it.method} ${it.endpoint}');
    }

    // ========= POLYGON POINTS REPLACE =========
    if (it.kind == 'polygon_points') {
      if (it.method != 'PUT') throw Exception('Unsupported polygon_points method: ${it.method}');
      final resp = await _dio.put(it.endpoint, options: optJson, data: jsonEncode(it.body));
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to replace polygon points (push)');
    }

    // ========= POLYGON PHOTO UPLOAD =========
    if (it.kind == 'polygon_photo') {
      if (it.method != 'POST') throw Exception('Unsupported polygon_photo method: ${it.method}');

      final filePath = (it.body['file_path'] ?? '').toString();
      if (filePath.trim().isEmpty) throw Exception('Missing file_path for polygon photo');

      final f = File(filePath);
      if (!await f.exists()) throw Exception('Photo file missing: $filePath');

      final opt = await _auth();
      final form = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          f.path,
          filename: 'poly_${it.body['plot_id'] ?? it.entityId ?? 'x'}_${it.body['seq'] ?? 'x'}.jpg',
          contentType: _photoMediaType(f.path),
        ),
      });

      final resp = await _dio.post(
        it.endpoint,
        options: opt.copyWith(contentType: 'multipart/form-data'),
        data: form,
      );

      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to upload polygon photo (push)');
    }

    throw Exception('Unsupported outbox kind: ${it.kind}');
  }

  /// Listener global: panggil sekali agar outbox otomatis dipush saat online.
  static Future<void> startAutoSyncListener() async {
    if (_syncListenerStarted) return;
    _syncListenerStarted = true;

    Future<void> flush() async {
      try {
        await PlotApi().pushPlotOutbox();
      } catch (_) {
        // ignore
      }
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // `onConnectivityChanged` does NOT emit the current state on subscribe, so
    // an app opened while already online would otherwise never sync a leftover
    // outbox. Flush once now to cover that case (pushPlotOutbox self-guards on
    // connectivity, so this is a no-op when offline).
    await flush();
  }

  /// Seluruh antrean modul ini, untuk halaman Data Offline.
  static Future<List<PendingOp>> pendingOps() =>
      PendingOps.read(_outboxKey);

}
