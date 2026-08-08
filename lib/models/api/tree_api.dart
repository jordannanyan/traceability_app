// lib/services/tree_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/get_trees.dart';
import 'package:traceability_app/utils/utils.dart';

/// ===============================
/// Hasil operasi offline-first
/// ===============================
class TreeOpResult {
  final bool appliedOnline;
  final bool queued;
  final int outboxCount;
  final String message;

  const TreeOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// ===============================
/// Outbox item untuk CRUD Tree
/// method: 'POST' | 'DELETE'
/// endpoint: '/trees' | '/trees/{id}'
/// body: map string scalar + optional 'photo_path'
/// entityId dipakai deduplikasi update/delete
/// ===============================
class _TreeCrudOutboxItem {
  final String id; // unique client op id (epoch millis)
  final String method; // 'POST' | 'DELETE'
  final String endpoint; // '/trees' | '/trees/{id}'
  final Map<String, dynamic> body; // scalar string-ish
  final int? entityId; // tree id (for update/delete)
  final int ts; // timestamp

  _TreeCrudOutboxItem({
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

  factory _TreeCrudOutboxItem.fromJson(Map<String, dynamic> j) =>
      _TreeCrudOutboxItem(
        id: (j['id'] ?? '').toString(),
        method: (j['method'] ?? '').toString(),
        endpoint: (j['endpoint'] ?? '').toString(),
        body: (j['body'] as Map? ?? const {}).cast<String, dynamic>(),
        entityId: j['entity_id'] is int
            ? (j['entity_id'] as int)
            : int.tryParse('${j['entity_id']}'),
        ts: (j['ts'] is int)
            ? (j['ts'] as int)
            : int.tryParse('${j['ts']}') ?? 0,
      );
}

class TreeApi {
  late final Dio _dio;

  // ------------ Outbox (SharedPreferences) ------------
  static const String _crudOutboxKey = 'outbox_tree_crud_v3';
  static const String _crudOutboxLastErrorKey =
      'outbox_tree_crud_last_error_v1';

  static bool _syncListenerStarted = false;

  // SINGLE-FLIGHT GUARD for push + throttle
  // Serializes outbox pushes across concurrent triggers / transient instances.
  static final Lock _outboxLock = Lock();
  static DateTime? _lastPushAt;

  // =============== PLOTS CACHE (by KTH / ALL / DETAIL) ===============
  static String _cachePlotsKthKey(int kthId, int perPage) =>
      'cache_plots_kth_${kthId}_pp$perPage';
  static String _cachePlotsKthTsKey(int kthId, int perPage) =>
      'cache_plots_kth_${kthId}_pp${perPage}_ts';

  static String _cacheAllPlotsKey(int page, int perPage) =>
      'cache_plots_all_p${page}_pp$perPage';
  static String _cacheAllPlotsTsKey(int page, int perPage) =>
      'cache_plots_all_p${page}_pp${perPage}_ts';

  static String _cachePlotDetailKey(int id) => 'cache_plot_detail_$id';
  static String _cachePlotDetailTsKey(int id) => 'cache_plot_detail_${id}_ts';

  // =============== TREES CACHE (LIST) ===============
  static String _cacheKthKey(int kthId, int page, int perPage) =>
      'cache_trees_kth_${kthId}_p${page}_pp$perPage';
  static String _cacheKthTsKey(int kthId, int page, int perPage) =>
      'cache_trees_kth_${kthId}_p${page}_pp${perPage}_ts';

  static String _cacheFarmerKey(int farmerId, int page, int perPage) =>
      'cache_trees_farmer_${farmerId}_p${page}_pp$perPage';
  static String _cacheFarmerTsKey(int farmerId, int page, int perPage) =>
      'cache_trees_farmer_${farmerId}_p${page}_pp${perPage}_ts';

  static String _cachePlotKey(int plotId, int page, int perPage) =>
      'cache_trees_plot_${plotId}_p${page}_pp$perPage';
  static String _cachePlotTsKey(int plotId, int page, int perPage) =>
      'cache_trees_plot_${plotId}_p${page}_pp${perPage}_ts';

  // =============== TREE DETAIL CACHE ===============
  static String _cacheDetailKey(int id) => 'cache_tree_detail_$id';
  static String _cacheDetailTsKey(int id) => 'cache_tree_detail_${id}_ts';

  // =============== PLOTS CACHE (per farmer) ===============
  static String _cachePlotsFarmerKey(int farmerId) =>
      'cache_plots_farmer_$farmerId';
  static String _cachePlotsFarmerTsKey(int farmerId) =>
      'cache_plots_farmer_${farmerId}_ts';

  /// Base origin for public storage files (Laravel `public/storage` symlink).
  static const String storageBaseUrl =
      'https://app.nbsvworldwide.com';

  /// Timeout profiles
  static const Duration _defaultConnectTimeout = Duration(seconds: 30);
  static const Duration _defaultReceiveTimeout = Duration(seconds: 45);
  static const Duration _defaultSendTimeout = Duration(seconds: 45);

  /// For upload endpoints that can take long (e.g., /trees with photo)
  static const Duration _uploadSendTimeout = Duration(minutes: 2);
  static const Duration _uploadReceiveTimeout = Duration(minutes: 2);

  /// Normalise a stored photo path to an absolute URL.
  ///
  /// DB stores paths inconsistently: `/storage/trees/x.jpg`, `storage/trees/x.jpg`,
  /// `/trees/x.jpg`, or `trees/x.jpg`. This always produces a URL with a single
  /// `/storage/` segment. If already absolute http(s), returned as-is (with
  /// localhost rewritten to prod host).
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

  TreeApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: _defaultConnectTimeout,
        receiveTimeout: _defaultReceiveTimeout,
        sendTimeout: _defaultSendTimeout,
        validateStatus: (_) => true,
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint(
              '➡️ ${o.method} ${o.baseUrl}${o.path} query=${o.queryParameters}',
            );
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
              '❌ DioException ${e.type} for ${e.requestOptions.method} ${e.requestOptions.uri}',
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

  // ================= Helpers umum =================

  static String _safeJson(dynamic data) {
    if (data is FormData) {
      final fields = {for (final e in data.fields) e.key: e.value};
      final files = data.files
          .map((e) => {'key': e.key, 'filename': e.value.filename})
          .toList();
      return 'FormData(fields:${jsonEncode(fields)}, files:${jsonEncode(files)})';
    }
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<Options> _auth({
    Map<String, String>? extraHeaders,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    String? contentType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) throw Exception('Token not found. Please log in again.');

    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (extraHeaders != null) ...extraHeaders,
      },
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      contentType: contentType,
    );
  }

  Never _throwHttp(Response resp, [String msg = 'HTTP error']) {
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

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<MultipartFile?> _maybeFile(String? path, String filename) async {
    if (path == null || path.trim().isEmpty) return null;
    final f = File(path.trim());
    if (!await f.exists()) return null;
    return MultipartFile.fromFile(
      f.path,
      filename: filename,
      contentType: _photoMediaType(f.path),
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

  /// Copy foto sumber ke folder outbox khusus supaya tidak hilang kalau
  /// file sumber dipindah/diganti sebelum sync. Mengembalikan path tujuan,
  /// atau null kalau sumber kosong/tidak ada.
  Future<String?> _persistOutboxPhoto(String? srcPath, String opTag) async {
    if (srcPath == null || srcPath.trim().isEmpty) return null;
    final src = File(srcPath.trim());
    if (!await src.exists()) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/tree_outbox_photos');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = srcPath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final dest = File('${dir.path}/outbox_$opTag.$ext');
      await src.copy(dest.path);
      return dest.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('_persistOutboxPhoto failed, using src path: $e');
      }
      return srcPath; // fallback ke path asli
    }
  }

  /// Hapus foto outbox setelah item berhasil di-push, supaya tidak menumpuk.
  Future<void> _deleteOutboxPhotoIfAny(Map<String, dynamic> body) async {
    final p = body['photo_path']?.toString();
    if (p == null || p.isEmpty) return;
    if (!p.contains('tree_outbox_photos')) return; // hanya hapus milik outbox
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Normalisasi map utk outbox (semua scalar jadi string, file path disimpan apa adanya)
  Map<String, dynamic> _stringifyBody(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) return;
      out[k] = v.toString();
    });
    return out;
  }

  /// Merge headers safely onto Options
  Options _mergeOptions(Options base, {Map<String, String>? headers}) {
    final mergedHeaders = <String, dynamic>{};
    if (base.headers != null) mergedHeaders.addAll(base.headers!);
    if (headers != null) mergedHeaders.addAll(headers);
    return base.copyWith(headers: mergedHeaders);
  }

  // ================= Cache helpers: PLOTS =================

  Future<void> _savePlotsKthCache({
    required int kthId,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cachePlotsKthKey(kthId, perPage), jsonEncode(data));
    await p.setInt(
      _cachePlotsKthTsKey(kthId, perPage),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<Map<String, dynamic>>?> _loadPlotsKthCacheModel(
    int kthId,
    int perPage,
  ) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cachePlotsKthKey(kthId, perPage));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final List list = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded as List);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<DateTime?> getPlotsCacheTimeKth(int kthId, {int perPage = 200}) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cachePlotsKthTsKey(kthId, perPage));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> _saveAllPlotsCache({
    required int page,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheAllPlotsKey(page, perPage), jsonEncode(data));
    await p.setInt(
      _cacheAllPlotsTsKey(page, perPage),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<Map<String, dynamic>>?> _loadAllPlotsCacheModel(
    int page,
    int perPage,
  ) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheAllPlotsKey(page, perPage));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final List list = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded as List);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _savePlotDetailCache({
    required int id,
    required Map<String, dynamic> data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cachePlotDetailKey(id), jsonEncode(data));
    await p.setInt(
      _cachePlotDetailTsKey(id),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>?> _loadPlotDetailCacheModel(int id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cachePlotDetailKey(id));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final map = (decoded is Map && decoded['data'] is Map)
        ? Map<String, dynamic>.from(decoded['data'])
        : Map<String, dynamic>.from(decoded as Map);
    return map;
  }

  Future<void> _savePlotsFarmerCache({
    required int farmerId,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cachePlotsFarmerKey(farmerId), jsonEncode(data));
    await p.setInt(
      _cachePlotsFarmerTsKey(farmerId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<Map<String, dynamic>>?> _loadPlotsFarmerCacheModel(
    int farmerId,
  ) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cachePlotsFarmerKey(farmerId));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final List list = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded as List);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<DateTime?> getPlotsCacheTimeFarmer(int farmerId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cachePlotsFarmerTsKey(farmerId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ====== NEW: scan cached farmer plot lists safely ======
  Future<List<List<Map<String, dynamic>>>> _scanAllPlotsFarmerCaches() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys();

    const prefix = 'cache_plots_farmer_';
    final farmerKeys = keys
        .where((k) => k.startsWith(prefix) && !k.endsWith('_ts'))
        .toList();

    final out = <List<Map<String, dynamic>>>[];
    for (final k in farmerKeys) {
      final raw = p.getString(k);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final List list = (decoded is Map && decoded['data'] is List)
            ? decoded['data'] as List
            : (decoded as List);
        out.add(
          list
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      } catch (_) {
        // ignore broken cache entry
      }
    }
    return out;
  }

  Map<String, dynamic>? _findPlotInLists(
    int plotId,
    Iterable<List<Map<String, dynamic>>> lists,
  ) {
    for (final list in lists) {
      for (final m in list) {
        final pid = _toInt(m['id']);
        if (pid == plotId) return m;
      }
    }
    return null;
  }

  /// Cached-first: GET /plots/{id}
  /// FIXED:
  /// - jangan pakai plotId sebagai farmerId
  /// - fallback scan ke cache list yang benar (all/kth/farmer caches)
  /// - jika ketemu dari list → simpan ke cache detail supaya next time tidak hilang
  Future<Map<String, dynamic>?> getPlotByIdCached(int id) async {
    final online = await _isOnline();

    // 1) ONLINE fetch detail
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/plots/$id', options: opt);
        if (resp.statusCode == 200) {
          final raw = resp.data;
          final map = (raw is Map && raw['data'] is Map)
              ? Map<String, dynamic>.from(raw['data'])
              : Map<String, dynamic>.from(raw as Map);
          await _savePlotDetailCache(id: id, data: map);
          return map;
        }
        _throwHttp(resp, 'Failed to fetch plot detail');
      } catch (_) {
        // fall through to cache
      }
    }

    // 2) CACHE detail
    final cachedDetail = await _loadPlotDetailCacheModel(id);
    if (cachedDetail != null) return cachedDetail;

    // 3) FALLBACK: scan list caches
    // 3a) all plots cache (common used)
    final all1 = await _loadAllPlotsCacheModel(1, 400);

    // 3b) kth plots caches (try multiple perPage variants)
    final prefs = await SharedPreferences.getInstance();
    final kthId = prefs.getInt('id') ?? 0;

    final kthLists = <List<Map<String, dynamic>>>[];
    if (kthId != 0) {
      for (final pp in const [200, 400, 500]) {
        final l = await _loadPlotsKthCacheModel(kthId, pp);
        if (l != null && l.isNotEmpty) kthLists.add(l);
      }
    }

    // 3c) scan all farmer plot caches (safe)
    final farmerLists = await _scanAllPlotsFarmerCaches();

    final hit = _findPlotInLists(id, [
      if (all1 != null) all1,
      ...kthLists,
      ...farmerLists,
    ]);

    if (hit != null) {
      // important: persist as detail so Upsert lock-by-id always works
      await _savePlotDetailCache(id: id, data: hit);
      return hit;
    }

    return null;
  }

  /// Cached-first: GET /plots/kth/{kthId}?per_page=...
  Future<List<Map<String, dynamic>>> getPlotsByKthIdCached(
    int kthId, {
    int perPage = 200,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get(
          '/plots/kth/$kthId',
          options: opt,
          queryParameters: {'per_page': perPage},
        );
        if (resp.statusCode == 200) {
          final List list = (resp.data is Map && resp.data['data'] is List)
              ? (resp.data['data'] as List)
              : (resp.data as List);
          final data = list
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          await _savePlotsKthCache(kthId: kthId, perPage: perPage, data: data);

          // bonus: prefill detail cache for faster by-id resolve
          for (final m in data) {
            final pid = _toInt(m['id']);
            if (pid != 0) {
              await _savePlotDetailCache(id: pid, data: m);
            }
          }

          return data;
        }
        _throwHttp(resp, 'Failed to fetch plots by KTH');
      } catch (_) {
        final cached = await _loadPlotsKthCacheModel(kthId, perPage);
        if (cached != null) return cached;
        return <Map<String, dynamic>>[];
      }
    }

    final cached = await _loadPlotsKthCacheModel(kthId, perPage);
    return cached ?? <Map<String, dynamic>>[];
  }

  /// Cached-first: GET /plots?page=..&per_page=..
  Future<List<Map<String, dynamic>>> getAllPlotsCached({
    int page = 1,
    int perPage = 200,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get(
          '/plots',
          options: opt,
          queryParameters: {'page': page, 'per_page': perPage},
        );
        if (resp.statusCode == 200) {
          final List list = (resp.data is Map && resp.data['data'] is List)
              ? (resp.data['data'] as List)
              : (resp.data as List);
          final data = list
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          await _saveAllPlotsCache(page: page, perPage: perPage, data: data);

          // bonus: prefill detail cache
          for (final m in data) {
            final pid = _toInt(m['id']);
            if (pid != 0) {
              await _savePlotDetailCache(id: pid, data: m);
            }
          }

          return data;
        }
        _throwHttp(resp, 'Failed to fetch plots');
      } catch (_) {
        final cached = await _loadAllPlotsCacheModel(page, perPage);
        if (cached != null) return cached;
        return <Map<String, dynamic>>[];
      }
    }

    final cached = await _loadAllPlotsCacheModel(page, perPage);
    return cached ?? <Map<String, dynamic>>[];
  }

  /// Cached-first: GET /plots/farmer/{farmerId}
  Future<List<Map<String, dynamic>>> getPlotsByFarmerIdCached(
    int farmerId,
  ) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/plots/farmer/$farmerId', options: opt);
        if (resp.statusCode == 200) {
          final List list = (resp.data is Map && resp.data['data'] is List)
              ? (resp.data['data'] as List)
              : (resp.data as List);
          final data = list
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          await _savePlotsFarmerCache(farmerId: farmerId, data: data);

          // bonus: prefill detail cache
          for (final m in data) {
            final pid = _toInt(m['id']);
            if (pid != 0) {
              await _savePlotDetailCache(id: pid, data: m);
            }
          }

          return data;
        }
        _throwHttp(resp, 'Failed to fetch plots by farmer');
      } catch (_) {
        final cached = await _loadPlotsFarmerCacheModel(farmerId);
        if (cached != null) return cached;
        return <Map<String, dynamic>>[];
      }
    }

    final cached = await _loadPlotsFarmerCacheModel(farmerId);
    return cached ?? <Map<String, dynamic>>[];
  }

  /// Pre-warm plots + trees cache for a list of farmers (best-effort).
  Future<void> prewarmPlotsAndTreesForFarmers(
    List<int> farmerIds, {
    int treesPerPage = 400,
  }) async {
    if (!await _isOnline()) return;
    try {
      final List<int> allPlotIds = [];
      for (final fid in farmerIds) {
        final plots = await getPlotsByFarmerIdCached(fid);
        for (final p in plots) {
          final pid = _toInt(p['id']);
          if (pid != 0) allPlotIds.add(pid);
        }
      }
      for (final pid in allPlotIds) {
        await getTreesByPlotIdCached(pid, page: 1, perPage: treesPerPage);
      }
    } catch (_) {
      // best-effort
    }
  }

  // ================= Cache helpers: TREES LIST =================

  Future<void> _saveKthCache({
    required int kthId,
    required int page,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKthKey(kthId, page, perPage), jsonEncode(data));
    await p.setInt(
      _cacheKthTsKey(kthId, page, perPage),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<GetTrees?> _loadKthCacheModel(int kthId, int page, int perPage) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKthKey(kthId, page, perPage));
    if (raw == null || raw.isEmpty) return null;
    return getTreesFromJson(raw);
  }

  Future<void> _saveFarmerCache({
    required int farmerId,
    required int page,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _cacheFarmerKey(farmerId, page, perPage),
      jsonEncode(data),
    );
    await p.setInt(
      _cacheFarmerTsKey(farmerId, page, perPage),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<GetTrees?> _loadFarmerCacheModel(
    int farmerId,
    int page,
    int perPage,
  ) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheFarmerKey(farmerId, page, perPage));
    if (raw == null || raw.isEmpty) return null;
    return getTreesFromJson(raw);
  }

  Future<void> _savePlotCache({
    required int plotId,
    required int page,
    required int perPage,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cachePlotKey(plotId, page, perPage), jsonEncode(data));
    await p.setInt(
      _cachePlotTsKey(plotId, page, perPage),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<GetTrees?> _loadPlotCacheModel(
    int plotId,
    int page,
    int perPage,
  ) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cachePlotKey(plotId, page, perPage));
    if (raw == null || raw.isEmpty) return null;
    return getTreesFromJson(raw);
  }

  /// Timestamp cache LIST by farmer
  Future<DateTime?> getTreesCacheTimeFarmer(
    int farmerId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheFarmerTsKey(farmerId, page, perPage));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// Timestamp cache LIST by KTH
  Future<DateTime?> getTreesCacheTimeKth(
    int kthId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheKthTsKey(kthId, page, perPage));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// Timestamp cache LIST by plot
  Future<DateTime?> getTreesCacheTimePlot(
    int plotId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cachePlotTsKey(plotId, page, perPage));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// ALIAS kompatibel buat kode lama
  Future<DateTime?> getTreesCacheTime(
    int farmerId, {
    int page = 1,
    int perPage = 20,
  }) {
    return getTreesCacheTimeFarmer(farmerId, page: page, perPage: perPage);
  }

  // ================= Cache helpers: TREE DETAIL =================

  Future<void> _saveTreeDetailCache({
    required int id,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheDetailKey(id), jsonEncode(data));
    await p.setInt(
      _cacheDetailTsKey(id),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Datum?> _loadTreeDetailCacheModel(int id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheDetailKey(id));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final map = (decoded is Map && decoded['data'] is Map)
        ? Map<String, dynamic>.from(decoded['data'])
        : Map<String, dynamic>.from(decoded as Map);
    return Datum.fromJson(map);
  }

  Future<DateTime?> getTreeDetailCacheTime(int id) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheDetailTsKey(id));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ================= API (GET) =================
  // Sesuai routes: GET /trees (index) + filter via query

  Future<GetTrees> getTrees({
    int? entitiesId,
    int? kthId,
    int? farmerId,
    int? plotId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final opt = await _auth();
    final resp = await _dio.get(
      '/trees',
      options: opt,
      queryParameters: {
        if (entitiesId != null) 'entities_id': entitiesId,
        if (kthId != null) 'kth_id': kthId,
        if (farmerId != null) 'farmer_id': farmerId,
        if (plotId != null) 'plot_id': plotId,
        'page': page,
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    if (resp.statusCode == 200) {
      return getTreesFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch trees');
  }

  /// cached-first by KTH id
  Future<GetTrees> getTreesByKthIdCached(
    int kthId, {
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final res = await getTrees(
          kthId: kthId,
          page: page,
          perPage: perPage,
          search: search,
        );
        await _saveKthCache(
          kthId: kthId,
          page: page,
          perPage: perPage,
          data: jsonDecode(getTreesToJson(res)),
        );
        return res;
      } catch (_) {
        final cached = await _loadKthCacheModel(kthId, page, perPage);
        if (cached != null) return cached;
        return GetTrees(
          currentPage: page,
          data: [],
          perPage: perPage,
          total: 0,
        );
      }
    }

    final cached = await _loadKthCacheModel(kthId, page, perPage);
    return cached ??
        GetTrees(currentPage: page, data: [], perPage: perPage, total: 0);
  }

  /// cached-first by farmer id
  Future<GetTrees> getTreesByFarmerIdCached(
    int farmerId, {
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final res = await getTrees(
          farmerId: farmerId,
          page: page,
          perPage: perPage,
          search: search,
        );
        await _saveFarmerCache(
          farmerId: farmerId,
          page: page,
          perPage: perPage,
          data: jsonDecode(getTreesToJson(res)),
        );
        return res;
      } catch (_) {
        final cached = await _loadFarmerCacheModel(farmerId, page, perPage);
        if (cached != null) return cached;
        return GetTrees(
          currentPage: page,
          data: [],
          perPage: perPage,
          total: 0,
        );
      }
    }

    final cached = await _loadFarmerCacheModel(farmerId, page, perPage);
    return cached ??
        GetTrees(currentPage: page, data: [], perPage: perPage, total: 0);
  }

  /// ALIAS kompatibel
  Future<GetTrees> getTreesByFarmerCached(
    int farmerId, {
    int page = 1,
    int perPage = 20,
    String? search,
  }) {
    return getTreesByFarmerIdCached(
      farmerId,
      page: page,
      perPage: perPage,
      search: search,
    );
  }

  /// cached-first by plot id
  Future<GetTrees> getTreesByPlotIdCached(
    int plotId, {
    int page = 1,
    int perPage = 50,
    String? search,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        final res = await getTrees(
          plotId: plotId,
          page: page,
          perPage: perPage,
          search: search,
        );
        await _savePlotCache(
          plotId: plotId,
          page: page,
          perPage: perPage,
          data: jsonDecode(getTreesToJson(res)),
        );
        return res;
      } catch (_) {
        final cached = await _loadPlotCacheModel(plotId, page, perPage);
        if (cached != null) return cached;
        return GetTrees(
          currentPage: page,
          data: [],
          perPage: perPage,
          total: 0,
        );
      }
    }

    final cached = await _loadPlotCacheModel(plotId, page, perPage);
    return cached ??
        GetTrees(currentPage: page, data: [], perPage: perPage, total: 0);
  }

  Future<Datum> getTreeById(int treeId) async {
    final opt = await _auth();
    final resp = await _dio.get('/trees/$treeId', options: opt);
    if (resp.statusCode == 200) {
      final data = (resp.data is Map)
          ? (resp.data['data'] ?? resp.data)
          : resp.data;
      return Datum.fromJson(Map<String, dynamic>.from(data));
    }
    _throwHttp(resp, 'Failed to fetch tree by ID');
  }

  /// Detail cached-first
  Future<Datum?> getTreeByIdCached(int treeId) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/trees/$treeId', options: opt);
        if (resp.statusCode == 200) {
          final raw = resp.data;
          final dataMap = (raw is Map && raw['data'] is Map)
              ? Map<String, dynamic>.from(raw['data'])
              : Map<String, dynamic>.from(raw as Map);
          await _saveTreeDetailCache(id: treeId, data: dataMap);
          return Datum.fromJson(dataMap);
        }
        final cached = await _loadTreeDetailCacheModel(treeId);
        if (cached != null) return cached;
        _throwHttp(resp, 'Failed to fetch tree by ID');
      } catch (_) {
        final cached = await _loadTreeDetailCacheModel(treeId);
        return cached;
      }
    }

    return _loadTreeDetailCacheModel(treeId);
  }

  // ================= Monitoring =================

  Future<Map<String, dynamic>?> getLatestMonitoringRaw(int treeId) async {
    final opt = await _auth();
    final resp = await _dio.get(
      '/trees/$treeId/monitorings/latest',
      options: opt,
    );
    if (resp.statusCode == 200) {
      final map = (resp.data is Map && resp.data['data'] is Map)
          ? Map<String, dynamic>.from(resp.data['data'])
          : Map<String, dynamic>.from(resp.data as Map);
      return map;
    }
    if (resp.statusCode == 404) return null;
    _throwHttp(resp, 'Failed to fetch latest monitoring');
  }

  // ================= API (Mutasi ONLINE) =================
  // POST /trees, PUT /trees/{id} (via _method), DELETE /trees/{id}

  Future<Datum> addTree({
    required int plotId,
    int? farmerId,
    String? treeName,
    String? species,
    DateTime? plantingDate,
    String? qrCode,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? photoBase64,
    String? photoFilePath,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    Response resp;

    final hasFile =
        photoFilePath != null &&
        photoFilePath.trim().isNotEmpty &&
        File(photoFilePath.trim()).existsSync();

    // Per-request timeout for slow upload endpoints
    final optUpload = await _auth(
      sendTimeout: _uploadSendTimeout,
      receiveTimeout: _uploadReceiveTimeout,
    );

    if (hasFile) {
      final photoFile = File(photoFilePath.trim());
      final photoSize = await photoFile.length();
      if (kDebugMode) {
        debugPrint('📸 photo size: ${(photoSize / 1024).toStringAsFixed(0)} KB ($photoFilePath)');
      }

      final form = FormData.fromMap({
        'plot_id': plotId,
        if (farmerId != null) 'farmer_id': farmerId,
        if (treeName != null) 'tree_name': treeName,
        if (species != null) 'species': species,
        if (plantingDate != null)
          'planting_date': plantingDate.toIso8601String(),
        if (qrCode != null) 'qr_code': qrCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        'photo': await MultipartFile.fromFile(
          photoFilePath.trim(),
          filename: 'tree.jpg',
          contentType: _photoMediaType(photoFilePath),
        ),
      });

      resp = await _dio.post(
        '/trees',
        data: form,
        options: optUpload,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } else {
      final optJson = _mergeOptions(
        optUpload,
        headers: {'Content-Type': 'application/json'},
      );
      final body = {
        'plot_id': plotId,
        if (farmerId != null) 'farmer_id': farmerId,
        if (treeName != null) 'tree_name': treeName,
        if (species != null) 'species': species,
        if (plantingDate != null)
          'planting_date': plantingDate.toIso8601String(),
        if (qrCode != null) 'qr_code': qrCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (photoBase64 != null) 'photo_base64': photoBase64,
      };
      resp = await _dio.post(
        '/trees',
        data: jsonEncode(body),
        options: optJson,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = (resp.data is Map)
          ? (resp.data['data'] ?? resp.data)
          : resp.data;
      return Datum.fromJson(Map<String, dynamic>.from(data));
    }
    _throwHttp(resp, 'Failed to add tree');
  }

  Future<Datum> editTree({
    required int id,
    int? plotId,
    int? farmerId,
    String? treeName,
    String? species,
    DateTime? plantingDate,
    String? qrCode,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? photoBase64,
    String? photoFilePath,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    Response resp;

    final hasFile =
        photoFilePath != null &&
        photoFilePath.trim().isNotEmpty &&
        File(photoFilePath.trim()).existsSync();

    final optUpload = await _auth(
      sendTimeout: _uploadSendTimeout,
      receiveTimeout: _uploadReceiveTimeout,
    );

    if (hasFile) {
      final form = FormData.fromMap({
        '_method': 'PUT',
        if (plotId != null) 'plot_id': plotId,
        if (farmerId != null) 'farmer_id': farmerId,
        if (treeName != null) 'tree_name': treeName,
        if (species != null) 'species': species,
        if (plantingDate != null)
          'planting_date': plantingDate.toIso8601String(),
        if (qrCode != null) 'qr_code': qrCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        'photo': await MultipartFile.fromFile(
          photoFilePath.trim(),
          filename: 'tree.jpg',
          contentType: _photoMediaType(photoFilePath),
        ),
      });
      resp = await _dio.post(
        '/trees/$id',
        data: form,
        options: optUpload,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } else {
      final optJson = _mergeOptions(
        optUpload,
        headers: {'Content-Type': 'application/json'},
      );
      final body = {
        '_method': 'PUT',
        if (plotId != null) 'plot_id': plotId,
        if (farmerId != null) 'farmer_id': farmerId,
        if (treeName != null) 'tree_name': treeName,
        if (species != null) 'species': species,
        if (plantingDate != null)
          'planting_date': plantingDate.toIso8601String(),
        if (qrCode != null) 'qr_code': qrCode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (photoBase64 != null) 'photo_base64': photoBase64,
      };
      resp = await _dio.post(
        '/trees/$id',
        data: jsonEncode(body),
        options: optJson,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    }

    if (resp.statusCode == 200) {
      final data = (resp.data is Map)
          ? (resp.data['data'] ?? resp.data)
          : resp.data;
      return Datum.fromJson(Map<String, dynamic>.from(data));
    }
    _throwHttp(resp, 'Failed to update tree');
  }

  Future<String> deleteTree(int id) async {
    final opt = await _auth(
      sendTimeout: _uploadSendTimeout,
      receiveTimeout: _uploadReceiveTimeout,
    );
    final resp = await _dio.delete('/trees/$id', options: opt);
    if (resp.statusCode == 200) {
      return (resp.data is Map && resp.data['message'] != null)
          ? resp.data['message'].toString()
          : 'Pohon dihapus.';
    }
    _throwHttp(resp, 'Failed to delete tree');
  }

  // ================= API (Mutasi OFFLINE-FIRST) =================

  Future<TreeOpResult> addTreeOfflineFirst({
    required int plotId,
    int? farmerId,
    String? treeName,
    String? species,
    DateTime? plantingDate,
    String? qrCode,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? photoPath, // path file lokal
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await addTree(
          plotId: plotId,
          farmerId: farmerId,
          treeName: treeName,
          species: species,
          plantingDate: plantingDate,
          qrCode: qrCode,
          latitude: latitude,
          longitude: longitude,
          accuracyM: accuracyM,
          photoFilePath: photoPath,
        );
        final pushed = await pushTreeOutbox();
        final count = await getTreeOutboxCount();
        return TreeOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0
              ? 'Tersinkron: $pushed aksi tertunda.'
              : 'Pohon ditambahkan.',
        );
      } catch (e) {
        // Online detected tapi HTTP gagal (timeout/captive portal/server down).
        // Jangan lempar error — fallback ke offline queue di bawah.
        if (kDebugMode) {
          debugPrint('addTree online failed, queueing offline: $e');
        }
      }
    }

    // OFFLINE → queue create
    final list = await _loadCrudOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Persist foto ke folder outbox khusus supaya tidak hilang kalau file
    // sumber dipindah/dihapus sebelum sync.
    final persistedPhoto = await _persistOutboxPhoto(photoPath, now.toString());

    final body = _stringifyBody({
      'plot_id': plotId,
      if (farmerId != null) 'farmer_id': farmerId,
      if (treeName != null) 'tree_name': treeName,
      if (species != null) 'species': species,
      if (plantingDate != null) 'planting_date': plantingDate.toIso8601String(),
      if (qrCode != null) 'qr_code': qrCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (persistedPhoto != null) 'photo_path': persistedPhoto,
    });

    list.add(
      _TreeCrudOutboxItem(
        id: now.toString(),
        method: 'POST',
        endpoint: '/trees',
        body: body,
        entityId: null,
        ts: now,
      ),
    );
    await _saveCrudOutbox(list);

    // Langsung coba push — kalau ternyata online (fallthrough dari try/catch
    // di atas atau koneksi baru muncul), data ter-sync segera.
    _tryPushSoon();

    return TreeOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: list.length,
      message: 'Tersimpan offline. Akan diunggah saat online.',
    );
  }

  Future<TreeOpResult> editTreeOfflineFirst({
    required int id,
    int? plotId,
    int? farmerId,
    String? treeName,
    String? species,
    DateTime? plantingDate,
    String? qrCode,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? photoPath,
  }) async {
    final online = await _isOnline();

    if (online) {
      try {
        await editTree(
          id: id,
          plotId: plotId,
          farmerId: farmerId,
          treeName: treeName,
          species: species,
          plantingDate: plantingDate,
          qrCode: qrCode,
          latitude: latitude,
          longitude: longitude,
          accuracyM: accuracyM,
          photoFilePath: photoPath,
        );
        final pushed = await pushTreeOutbox();
        final count = await getTreeOutboxCount();
        return TreeOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0
              ? 'Tersinkron: $pushed aksi tertunda.'
              : 'Pohon diperbarui.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('editTree online failed, queueing offline: $e');
        }
      }
    }

    // OFFLINE → queue edit (POST + _method=PUT)
    final list = await _loadCrudOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    final persistedPhoto =
        await _persistOutboxPhoto(photoPath, '${id}_$now');

    final body = _stringifyBody({
      '_method': 'PUT',
      if (plotId != null) 'plot_id': plotId,
      if (farmerId != null) 'farmer_id': farmerId,
      if (treeName != null) 'tree_name': treeName,
      if (species != null) 'species': species,
      if (plantingDate != null) 'planting_date': plantingDate.toIso8601String(),
      if (qrCode != null) 'qr_code': qrCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (persistedPhoto != null) 'photo_path': persistedPhoto,
    });

    list.add(
      _TreeCrudOutboxItem(
        id: now.toString(),
        method: 'POST',
        endpoint: '/trees/$id',
        body: body,
        entityId: id,
        ts: now,
      ),
    );

    final deduped = _dedupeCrudByEntityId(list);
    await _saveCrudOutbox(deduped);

    _tryPushSoon();

    return TreeOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan diunggah saat online.',
    );
  }

  Future<TreeOpResult> deleteTreeOfflineFirst(int id) async {
    final online = await _isOnline();

    if (online) {
      try {
        await deleteTree(id);
        final pushed = await pushTreeOutbox();
        final count = await getTreeOutboxCount();
        return TreeOpResult(
          appliedOnline: true,
          queued: false,
          outboxCount: count,
          message: pushed > 0
              ? 'Tersinkron: $pushed aksi tertunda.'
              : 'Pohon dihapus.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('deleteTree online failed, queueing offline: $e');
        }
      }
    }

    final list = await _loadCrudOutbox();
    final now = DateTime.now().millisecondsSinceEpoch;

    list.add(
      _TreeCrudOutboxItem(
        id: now.toString(),
        method: 'DELETE',
        endpoint: '/trees/$id',
        body: const {},
        entityId: id,
        ts: now,
      ),
    );

    final deduped = _dedupeCrudByEntityId(list);
    await _saveCrudOutbox(deduped);

    _tryPushSoon();

    return TreeOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan diunggah saat online.',
    );
  }

  /// Coba push outbox setelah delay singkat secara berulang sampai habis.
  /// Non-blocking — jalan di background. Aman dipanggil berkali-kali
  /// karena pushTreeOutbox sudah punya single-flight guard.
  void _tryPushSoon() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final pushed = await pushTreeOutbox();
        // Kalau berhasil push ≥1, coba lagi — mungkin masih ada sisa.
        if (pushed > 0) {
          final remaining = await getTreeOutboxCount();
          if (remaining > 0) {
            if (kDebugMode) {
              debugPrint('🔄 outbox: pushed $pushed, remaining $remaining — retrying in 3s');
            }
            _tryPushSoon();
          }
        }
      } catch (_) {}
    });
  }

  // ================= Outbox storage =================

  Future<List<_TreeCrudOutboxItem>> _loadCrudOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_crudOutboxKey) ?? <String>[];

    final list =
        raw
            .map(
              (s) => _TreeCrudOutboxItem.fromJson(
                Map<String, dynamic>.from(jsonDecode(s) as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));

    return list;
  }

  Future<void> _saveCrudOutbox(List<_TreeCrudOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _crudOutboxKey,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  List<_TreeCrudOutboxItem> _dedupeCrudByEntityId(List<_TreeCrudOutboxItem> l) {
    final map = <int, _TreeCrudOutboxItem>{};
    final others = <_TreeCrudOutboxItem>[];

    for (final it in l) {
      if (it.entityId == null) {
        // create without server id: keep as-is
        others.add(it);
      } else {
        final id = it.entityId!;
        final prev = map[id];
        if (prev == null || it.ts >= prev.ts) {
          map[id] = it;
        }
      }
    }

    final vals = map.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final all = <_TreeCrudOutboxItem>[...others, ...vals]
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return all;
  }

  Future<int> getTreeOutboxCount() async => (await _loadCrudOutbox()).length;

  /// Queued tree ops, indexed for a list screen: creates to render as extra
  /// rows plus the pending state of already-synced rows. Read-only view of the
  /// same queue [pushTreeOutbox] drains.
  static Future<PendingIndex> pendingIndex() async =>
      PendingIndex.from(await PendingOps.read(_crudOutboxKey));

  /// Turns a queued create into a list row. The body holds the same snake_case
  /// fields the server returns, so the normal parser applies — only the id and
  /// timestamp are synthesised, and the id is negative to mark it as local.
  static Datum pendingTreeRow(PendingOp op) => Datum.fromJson({
    ...op.body,
    'id': op.localId,
    'created_at': op.queuedAt.toIso8601String(),
    'updated_at': op.queuedAt.toIso8601String(),
  });

  Future<String?> getLastTreeOutboxError() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_crudOutboxLastErrorKey);
    return (s == null || s.trim().isEmpty) ? null : s;
  }

  Future<void> clearLastTreeOutboxError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_crudOutboxLastErrorKey);
  }

  Future<void> _setLastOutboxError(String? msg) async {
    final prefs = await SharedPreferences.getInstance();
    if (msg == null || msg.trim().isEmpty) {
      await prefs.remove(_crudOutboxLastErrorKey);
    } else {
      await prefs.setString(_crudOutboxLastErrorKey, msg);
    }
  }

  // ================= PUSH Outbox =================
  /// Push outbox items saat online. Batch save tiap beberapa item supaya
  /// tidak overload SharedPreferences pada antrian besar (ratusan item).
  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushTreeOutbox({int maxItems = 50}) =>
      _outboxLock.synchronized(() => _pushTreeOutboxLocked(maxItems: maxItems));

  Future<int> _pushTreeOutboxLocked({int maxItems = 50}) async {
    if (!await _isOnline()) return 0;

    await _setLastOutboxError(null);

    var list = await _loadCrudOutbox();
      if (list.isEmpty) return 0;

      if (kDebugMode) {
        debugPrint('📤 pushTreeOutbox: ${list.length} items in queue, max $maxItems');
      }

      int success = 0;
      int processed = 0;
      int sinceLastSave = 0;
      const saveEvery = 5; // save ke SharedPreferences tiap 5 item, bukan tiap 1

      for (final item in List<_TreeCrudOutboxItem>.from(list)) {
        if (processed >= maxItems) break;

        // Cek ulang koneksi tiap 10 item — bisa putus di tengah batch besar
        if (processed > 0 && processed % 10 == 0) {
          if (!await _isOnline()) {
            if (kDebugMode) debugPrint('📤 connection lost mid-push, stopping');
            break;
          }
        }

        processed++;

        try {
          await _pushCrudItemOnline(item);
          success++;

          await _deleteOutboxPhotoIfAny(item.body);
          list.removeWhere((e) => e.id == item.id);

          sinceLastSave++;
          // Batch save: tulis ke SharedPreferences tiap N item, bukan tiap 1
          if (sinceLastSave >= saveEvery) {
            await _saveCrudOutbox(list);
            sinceLastSave = 0;
          }
        } catch (e) {
          final errMsg =
              'Failed item ${item.method} ${item.endpoint} (opId=${item.id}): $e';
          await _setLastOutboxError(errMsg);

          // Poison (invalid 4xx) → drop and keep going so one bad item never
          // blocks the queue. Otherwise (network/5xx/auth/timeout/local) → stop
          // and retry the whole batch later.
          if (isPoisonOutboxError(e)) {
            if (kDebugMode) {
              debugPrint('📤 poison item dropped: ${item.endpoint} — $e');
            }
            await _deleteOutboxPhotoIfAny(item.body);
            list.removeWhere((x) => x.id == item.id);
            sinceLastSave++;
            continue;
          }
          break;
        }
      }

      // Final save untuk sisa yang belum di-save
      if (sinceLastSave > 0) {
        await _saveCrudOutbox(list);
      }

      if (kDebugMode) {
        debugPrint('📤 pushTreeOutbox done: $success/$processed pushed, ${list.length} remaining');
      }

      return success;
  }

  Future<void> _pushCrudItemOnline(_TreeCrudOutboxItem it) async {
    // Idempotency header to avoid duplicates if client retries
    final idempotentHeader = {'Idempotency-Key': it.id};

    // Make push operations use upload timeout too (server can be slow)
    final optUpload = await _auth(
      extraHeaders: idempotentHeader,
      sendTimeout: _uploadSendTimeout,
      receiveTimeout: _uploadReceiveTimeout,
    );

    if (it.method == 'POST' && it.endpoint == '/trees') {
      final form = await _buildTreeFormData(it.body);
      final resp = await _dio.post(it.endpoint, data: form, options: optUpload);
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      _throwHttp(resp, 'Failed to add tree (push)');
    }

    if (it.method == 'POST' && it.endpoint.startsWith('/trees/')) {
      final form = await _buildTreeFormData(it.body);

      // ensure _method=PUT exists
      if (!form.fields.any((e) => e.key == '_method')) {
        form.fields.add(const MapEntry('_method', 'PUT'));
      }

      final resp = await _dio.post(it.endpoint, data: form, options: optUpload);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update tree (push)');
    }

    if (it.method == 'DELETE' && it.endpoint.startsWith('/trees/')) {
      final resp = await _dio.delete(it.endpoint, options: optUpload);
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete tree (push)');
    }

    throw Exception('Unsupported outbox item: ${it.method} ${it.endpoint}');
  }

  Future<FormData> _buildTreeFormData(Map<String, dynamic> body) async {
    final form = FormData();

    // Scalars
    const scalarKeys = <String>[
      'plot_id',
      'farmer_id',
      'tree_name',
      'species',
      'planting_date',
      'qr_code',
      'latitude',
      'longitude',
      'accuracy_m',
      '_method',
    ];

    for (final k in scalarKeys) {
      final v = body[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        form.fields.add(MapEntry(k, v.toString()));
      }
    }

    // Photo (optional)
    final photo = await _maybeFile(body['photo_path']?.toString(), 'tree.jpg');
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
      final now = DateTime.now();
      if (_lastPushAt != null &&
          now.difference(_lastPushAt!) < const Duration(seconds: 4)) {
        return;
      }
      _lastPushAt = now;

      try {
        final api = TreeApi();
        if (!await api._isOnline()) return;
        // Loop sampai semua outbox terdorong
        while (true) {
          final pushed = await api.pushTreeOutbox();
          if (pushed == 0) break;
          final remaining = await api.getTreeOutboxCount();
          if (remaining == 0) break;
          // Jeda antar batch supaya tidak membanjiri server
          await Future.delayed(const Duration(seconds: 3));
          // Re-check koneksi
          if (!await api._isOnline()) break;
        }
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((event) async {
      final online = event.isNotEmpty && event.any((r) => r != ConnectivityResult.none);
      if (!online) return;
      await flush();
    });

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (flush() checks connectivity itself).
    await flush();
  }
}
