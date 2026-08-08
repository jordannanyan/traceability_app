// lib/models/api/farmer_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:traceability_app/models/api/outbox_error.dart';
import 'package:traceability_app/utils/utils.dart';

// LIST model you provided (controller /farmers returns an array)
import 'package:traceability_app/models/get_farmers_by_kth_id.dart';

// Detail model used elsewhere in your app (controller /farmers/{id})
import 'package:traceability_app/models/get_farmer_by_id.dart';
import 'package:traceability_app/models/update_farmer.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

/// Hasil operasi offline-first (add/edit/delete)
class FarmerOpResult {
  final bool appliedOnline; // langsung ke server sekarang
  final bool queued;        // disimpan di outbox
  final int outboxCount;    // jumlah task outbox saat ini
  final String message;     // pesan untuk UI

  const FarmerOpResult({
    required this.appliedOnline,
    required this.queued,
    required this.outboxCount,
    required this.message,
  });
}

/// Outbox item untuk operasi farmer
class _FarmerOutboxItem {
  final String id;        // unik, epoch millis string
  final String method;    // 'POST' | 'POST_PUT' | 'DELETE'
  final String endpoint;  // '/farmers' atau '/farmers/{id}'
  final Map<String, dynamic> body; // payload JSON (tanpa file)
  final int? entityId;    // farmerId jika ada (untuk dedupe)
  final String? fotoPath; // path file foto lokal (opsional)
  final int ts;           // timestamp millis

  _FarmerOutboxItem({
    required this.id,
    required this.method,
    required this.endpoint,
    required this.body,
    required this.entityId,
    required this.ts,
    this.fotoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'body': body,
        'entity_id': entityId,
        'ts': ts,
        'foto_path': fotoPath,
      };

  factory _FarmerOutboxItem.fromJson(Map<String, dynamic> j) => _FarmerOutboxItem(
        id: j['id'] as String,
        method: j['method'] as String,
        endpoint: j['endpoint'] as String,
        body: (j['body'] as Map).cast<String, dynamic>(),
        entityId: j['entity_id'] as int?,
        ts: j['ts'] as int,
        fotoPath: j['foto_path'] as String?,
      );
}

class FarmerApi {
  late final Dio _dio;

  // ========= Outbox (SharedPreferences) =========
  static const String _outboxKey = 'outbox_farmer_v1';
  static bool _syncListenerStarted = false;

  // Serializes outbox pushes across concurrent triggers / transient instances.
  static final Lock _outboxLock = Lock();

  // ========= Cache keys (LIST) =========
  static String _cacheFarmersKey({int? kthId, int? entitiesId, String? search}) {
    final k = kthId?.toString() ?? '-';
    final e = entitiesId?.toString() ?? '-';
    final s = (search == null || search.isEmpty) ? '-' : search;
    return 'cache_farmers_k=$k-e=$e-s=$s';
  }

  static String _cacheFarmersTsKey({int? kthId, int? entitiesId, String? search}) {
    return '${_cacheFarmersKey(kthId: kthId, entitiesId: entitiesId, search: search)}_ts';
  }

  // ========= Cache keys (DETAIL by ID) =========
  static String _cacheByIdKey(int id) => 'cache_farmer_$id';
  static String _cacheByIdTsKey(int id) => 'cache_farmer_${id}_ts';

  FarmerApi() {
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
            if (o.queryParameters.isNotEmpty) {
              debugPrint('   query: ${jsonEncode(o.queryParameters)}');
            }
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

  // agro-api wraps list responses as { data: [...] }; the old API returned a
  // bare array. Accept both so the KTH farmer list is never empty.
  static List<dynamic> _asList(dynamic body) {
    if (body is List) return body;
    if (body is Map && body['data'] is List) return body['data'] as List;
    return const <dynamic>[];
  }

  static String _safeJson(dynamic data) {
    if (data is FormData) {
      final fieldsMap = <String, String>{};
      for (final e in data.fields) {
        fieldsMap[e.key] = e.value;
      }
      final files = data.files.map((e) => {'key': e.key, 'filename': e.value.filename}).toList();
      return 'FormData(fields: ${jsonEncode(fieldsMap)}, files: ${jsonEncode(files)})';
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

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
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

  // ================= Outbox helpers =================

  Future<List<_FarmerOutboxItem>> _loadOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_outboxKey) ?? <String>[];
    final list = raw.map((s) => _FarmerOutboxItem.fromJson(jsonDecode(s))).toList();
    list.sort((a, b) => a.ts.compareTo(b.ts));
    return list;
  }

  Future<void> _saveOutbox(List<_FarmerOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _outboxKey,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  List<_FarmerOutboxItem> _dedupeByEntityId(List<_FarmerOutboxItem> l) {
    final map = <int, _FarmerOutboxItem>{};
    final others = <_FarmerOutboxItem>[];
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
    final all = <_FarmerOutboxItem>[...others, ...vals]
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return all;
  }

  Future<int> getFarmerOutboxCount() async {
    final l = await _loadOutbox();
    return l.length;
  }

  // ================= Cache (LIST) =================

  Future<void> _saveFarmersCache({
    int? kthId,
    int? entitiesId,
    String? search,
    required dynamic data,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheFarmersKey(kthId: kthId, entitiesId: entitiesId, search: search), jsonEncode(data));
    await p.setInt(_cacheFarmersTsKey(kthId: kthId, entitiesId: entitiesId, search: search), DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<GetFarmerByKthId>?> _loadFarmersCacheModel({
    int? kthId,
    int? entitiesId,
    String? search,
  }) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheFarmersKey(kthId: kthId, entitiesId: entitiesId, search: search));
    if (raw == null || raw.isEmpty) return null;
    return getFarmerByKthIdFromJson(raw);
  }

  Future<DateTime?> getFarmersCacheTime({int? kthId, int? entitiesId, String? search}) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheFarmersTsKey(kthId: kthId, entitiesId: entitiesId, search: search));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ================= Cache (DETAIL by ID) =================

  Future<void> _saveByIdCache(int id, dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheByIdKey(id), jsonEncode(data));
    await p.setInt(_cacheByIdTsKey(id), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetFarmerById?> _loadByIdCacheModel(int id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheByIdKey(id));
    if (raw == null || raw.isEmpty) return null;
    return getFarmerByIdFromJson(raw);
  }

  Future<DateTime?> getFarmerCacheTime(int id) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheByIdTsKey(id));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ================= API (GET LIST) =================

  /// Online: ambil farmers (mendukung kth_id, entities_id, search).
  /// Controller mengembalikan array JSON.
  Future<List<GetFarmerByKthId>> getFarmers({
    int? kthId,
    int? entitiesId,
    String? search,
  }) async {
    final opt = await _auth();
    final qp = <String, dynamic>{
      if (kthId != null) 'kth_id': kthId,
      if (entitiesId != null) 'entities_id': entitiesId,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final resp = await _dio.get('/farmers', options: opt, queryParameters: qp);
    if (resp.statusCode == 200) {
      final list = _asList(resp.data);
      return getFarmerByKthIdFromJson(jsonEncode(list));
    }
    _throwHttp(resp, 'Failed to fetch farmers');
  }

  /// Cached-first (offline-first) untuk LIST.
  ///
  /// Selalu mengembalikan data (segar bila server menjawab, kalau tidak dari
  /// cache) **beserta alasannya** lewat [CachedResult.outcome]. Sebelumnya
  /// kegagalan refresh — termasuk 401 karena sesi hangus — dikembalikan sebagai
  /// cache lama tanpa tanda apa pun, sehingga daftar tidak pernah bertambah
  /// walau ditarik-refresh berkali-kali dan tak ada pesan yang menjelaskannya.
  Future<CachedResult<List<GetFarmerByKthId>>> getFarmersCached({
    int? kthId,
    int? entitiesId,
    String? search,
  }) async {
    Future<CachedResult<List<GetFarmerByKthId>>> fallback(
      RefreshOutcome outcome,
    ) async {
      final cached = await _loadFarmersCacheModel(
        kthId: kthId,
        entitiesId: entitiesId,
        search: search,
      );
      return CachedResult(cached ?? <GetFarmerByKthId>[], outcome);
    }

    if (!await _isOnline()) return fallback(RefreshOutcome.offlineCache);

    try {
      final opt = await _auth();
      final qp = <String, dynamic>{
        if (kthId != null) 'kth_id': kthId,
        if (entitiesId != null) 'entities_id': entitiesId,
        if (search != null && search.isNotEmpty) 'search': search,
      };
      final resp = await _dio.get('/farmers', options: opt, queryParameters: qp);

      if (resp.statusCode == 200) {
        final list = _asList(resp.data);
        // Cache the bare array (the model + cache loader expect a JSON array).
        await _saveFarmersCache(
          kthId: kthId,
          entitiesId: entitiesId,
          search: search,
          data: list,
        );
        return CachedResult.fresh(getFarmerByKthIdFromJson(jsonEncode(list)));
      }

      // The client uses `validateStatus: (_) => true`, so a rejected session
      // arrives here as a plain response rather than an exception.
      return fallback(
        SessionMonitor.isSessionRejection(resp.statusCode)
            ? RefreshOutcome.unauthorized
            : RefreshOutcome.refreshFailed,
      );
    } catch (_) {
      return fallback(RefreshOutcome.refreshFailed);
    }
  }

  // ================= API (GET DETAIL by ID) =================

  /// Online only: detail petani
  Future<GetFarmerById> getFarmerById(int farmerId) async {
    final opt = await _auth();
    final resp = await _dio.get('/farmers/$farmerId', options: opt);
    if (resp.statusCode == 200) {
      // simpan cache mentah (sesuai model GetFarmerById)
      await _saveByIdCache(farmerId, resp.data);
      return getFarmerByIdFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to fetch farmer by ID');
  }

  /// Cached-first (offline-first): detail petani
  Future<GetFarmerById> getFarmerByIdCached(int farmerId) async {
    final online = await _isOnline();
    if (online) {
      try {
        final opt = await _auth();
        final resp = await _dio.get('/farmers/$farmerId', options: opt);
        if (resp.statusCode == 200) {
          await _saveByIdCache(farmerId, resp.data);
          return getFarmerByIdFromJson(jsonEncode(resp.data));
        }
        final cached = await _loadByIdCacheModel(farmerId);
        if (cached != null) return cached;
        _throwHttp(resp, 'Failed to fetch farmer by ID');
      } catch (_) {
        final cached = await _loadByIdCacheModel(farmerId);
        if (cached != null) return cached;
        // fallback minimal
        return GetFarmerById(message: 'online-error-no-cache', data: null);
      }
    } else {
      final cached = await _loadByIdCacheModel(farmerId);
      if (cached != null) return cached;
      return GetFarmerById(message: 'offline-no-cache', data: null);
    }
  }

  // ================= API (Mutasi ONLINE murni) =================

  Future<String> addFarmer(Map<String, dynamic> fields) async {
    fields.removeWhere((k, v) => v == null);

    Response<dynamic> resp;
    final foto = fields['foto'];
    final isFotoPath = (foto is String) && foto.isNotEmpty && File(foto).existsSync();

    if (isFotoPath) {
      final form = FormData();
      fields.forEach((k, v) {
        if (k == 'foto') return;
        form.fields.add(MapEntry(k, v.toString()));
      });
      form.files.add(MapEntry(
        'foto',
        await MultipartFile.fromFile(foto, filename: foto.split('/').last, contentType: _photoMediaType(foto)),
      ));
      resp = await _dio.post('/farmers', data: form, options: await _auth());
    } else {
      resp = await _dio.post(
        '/farmers',
        data: jsonEncode(fields),
        options: await _auth(extraHeaders: {'Content-Type': 'application/json'}),
      );
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return resp.data is Map && (resp.data as Map)['message'] != null
          ? (resp.data as Map)['message'].toString()
          : 'Farmer created';
    }
    _throwHttp(resp, 'Failed to add farmer');
  }

  /// Generic edit (JSON atau multipart, method spoofing)
  Future<UpdateFarmer> updateFarmerAll(int farmerId, Map<String, dynamic> fields) async {
    fields.removeWhere((k, v) => v == null);

    final foto = fields['foto'];
    final isFotoPath = (foto is String) && foto.isNotEmpty && File(foto).existsSync();

    Response<dynamic> resp;
    if (isFotoPath) {
      final form = FormData();
      form.fields.add(const MapEntry('_method', 'PUT'));
      fields.forEach((k, v) {
        if (k == 'foto') return;
        form.fields.add(MapEntry(k, v.toString()));
      });
      form.files.add(MapEntry(
        'foto',
        await MultipartFile.fromFile(foto, filename: foto.split('/').last, contentType: _photoMediaType(foto)),
      ));
      resp = await _dio.post('/farmers/$farmerId', data: form, options: await _auth());
    } else {
      final data = Map<String, dynamic>.from(fields)..['_method'] = 'PUT';
      resp = await _dio.post(
        '/farmers/$farmerId',
        data: jsonEncode(data),
        options: await _auth(extraHeaders: {'Content-Type': 'application/json'}),
      );
    }

    if (resp.statusCode == 200) {
      // refresh cache detail (best effort)
      try {
        final opt = await _auth();
        final fresh = await _dio.get('/farmers/$farmerId', options: opt);
        if (fresh.statusCode == 200) {
          await _saveByIdCache(farmerId, fresh.data);
        }
      } catch (_) {}
      return updateFarmerFromJson(jsonEncode(resp.data));
    }
    _throwHttp(resp, 'Failed to update farmer');
  }

  Future<String> deleteFarmer(int id) async {
    final resp = await _dio.delete('/farmers/$id', options: await _auth());
    if (resp.statusCode == 200) {
      return resp.data is Map && (resp.data as Map)['message'] != null
          ? (resp.data as Map)['message'].toString()
          : 'Farmer deleted';
    }
    _throwHttp(resp, 'Failed to delete farmer');
  }

  // ================= API (Mutasi OFFLINE-FIRST) =================

  Future<FarmerOpResult> addFarmerOfflineFirst(Map<String, dynamic> fields) async {
    String? fotoPath;
    if (fields.containsKey('foto')) {
      final f = fields['foto'];
      if (f is String && f.isNotEmpty && File(f).existsSync()) {
        fotoPath = f;
      }
    }

    final online = await _isOnline();
    if (online) {
      await addFarmer(fields);
      final pushed = await pushFarmerOutbox();
      final count = await getFarmerOutboxCount();
      return FarmerOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Farmer ditambahkan.',
      );
    }

    final list = await _loadOutbox();
    final body = Map<String, dynamic>.from(fields)..remove('foto');
    list.add(_FarmerOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST',
      endpoint: '/farmers',
      body: body,
      entityId: null,
      ts: DateTime.now().millisecondsSinceEpoch,
      fotoPath: fotoPath,
    ));
    await _saveOutbox(list);

    return const FarmerOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: 0, // not used by UI typically
      message: 'Tersimpan offline. Akan disinkronkan saat online.',
    );
  }

  /// Wrapper agar kompatibel dgn pemanggil lama
  Future<FarmerOpResult> updateFarmerAllOfflineFirst(
    int farmerId,
    Map<String, dynamic> fields,
  ) async {
    return editFarmerOfflineFirst(farmerId, fields);
  }

  Future<FarmerOpResult> editFarmerOfflineFirst(int id, Map<String, dynamic> fields) async {
    String? fotoPath;
    if (fields.containsKey('foto')) {
      final f = fields['foto'];
      if (f is String && f.isNotEmpty && File(f).existsSync()) {
        fotoPath = f;
      }
    }

    final online = await _isOnline();
    if (online) {
      await updateFarmerAll(id, fields);
      final pushed = await pushFarmerOutbox();
      final count = await getFarmerOutboxCount();
      return FarmerOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Profil petani diperbarui.',
      );
    }

    final list = await _loadOutbox();
    final body = Map<String, dynamic>.from(fields)..remove('foto')..['_method'] = 'PUT';
    list.add(_FarmerOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'POST_PUT',
      endpoint: '/farmers/$id',
      body: body,
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
      fotoPath: fotoPath,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return FarmerOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Perubahan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  Future<FarmerOpResult> deleteFarmerOfflineFirst(int id) async {
    final online = await _isOnline();

    if (online) {
      await deleteFarmer(id);
      final pushed = await pushFarmerOutbox();
      final count = await getFarmerOutboxCount();
      return FarmerOpResult(
        appliedOnline: true,
        queued: false,
        outboxCount: count,
        message: pushed > 0 ? 'Tersinkron: $pushed aksi tertunda.' : 'Farmer dihapus.',
      );
    }

    final list = await _loadOutbox();
    list.add(_FarmerOutboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: 'DELETE',
      endpoint: '/farmers/$id',
      body: const {},
      entityId: id,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    final deduped = _dedupeByEntityId(list);
    await _saveOutbox(deduped);

    return FarmerOpResult(
      appliedOnline: false,
      queued: true,
      outboxCount: deduped.length,
      message: 'Penghapusan disimpan offline. Akan disinkronkan saat online.',
    );
  }

  // ================= Outbox push =================

  /// Serialized via [_outboxLock] so concurrent triggers never run in parallel.
  Future<int> pushFarmerOutbox() =>
      _outboxLock.synchronized(_pushFarmerOutboxLocked);

  Future<int> _pushFarmerOutboxLocked() async {
    if (!await _isOnline()) return 0;

    var list = await _loadOutbox();
    if (list.isEmpty) return 0;

    int success = 0;
    for (final item in List<_FarmerOutboxItem>.from(list)) {
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

  Future<void> _pushItemOnline(_FarmerOutboxItem it) async {
    // Multipart jika ada fotoPath dan file masih ada
    if ((it.fotoPath != null) && it.fotoPath!.isNotEmpty && File(it.fotoPath!).existsSync()) {
      final form = FormData();
      it.body.forEach((k, v) => form.fields.add(MapEntry(k, v.toString())));
      form.files.add(MapEntry(
        'foto',
        await MultipartFile.fromFile(it.fotoPath!, filename: it.fotoPath!.split('/').last, contentType: _photoMediaType(it.fotoPath!)),
      ));

      if (it.method == 'POST' && it.endpoint == '/farmers') {
        final resp = await _dio.post(it.endpoint, data: form, options: await _auth());
        if (resp.statusCode == 200 || resp.statusCode == 201) return;
        _throwHttp(resp, 'Failed to add farmer (push)');
      } else if (it.method == 'POST_PUT' && it.endpoint.startsWith('/farmers/')) {
        final resp = await _dio.post(it.endpoint, data: form, options: await _auth());
        if (resp.statusCode == 200) return;
        _throwHttp(resp, 'Failed to update farmer (push)');
      } else {
        throw Exception('Unsupported multipart outbox item: ${it.method} ${it.endpoint}');
      }
    }

    // JSON
    final optJson = await _auth(extraHeaders: {'Content-Type': 'application/json'});
    if (it.method == 'POST' && it.endpoint == '/farmers') {
      final resp = await _dio.post(it.endpoint, options: optJson, data: jsonEncode(it.body));
      if (resp.statusCode == 200 || resp.statusCode == 201) return;
      _throwHttp(resp, 'Failed to add farmer (push)');
    } else if (it.method == 'POST_PUT' && it.endpoint.startsWith('/farmers/')) {
      final resp = await _dio.post(it.endpoint, options: optJson, data: jsonEncode(it.body));
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to update farmer (push)');
    } else if (it.method == 'DELETE' && it.endpoint.startsWith('/farmers/')) {
      final resp = await _dio.delete(it.endpoint, options: await _auth());
      if (resp.statusCode == 200) return;
      _throwHttp(resp, 'Failed to delete farmer (push)');
    } else {
      throw Exception('Unsupported outbox item: ${it.method} ${it.endpoint}');
    }
  }

  /// Listener global: panggil sekali (misal setelah login) agar outbox otomatis dipush saat online.
  static Future<void> startAutoSyncListener() async {
    if (_syncListenerStarted) return;
    _syncListenerStarted = true;

    Future<void> flush() async {
      try {
        await FarmerApi().pushFarmerOutbox();
      } catch (_) {}
    }

    Connectivity().onConnectivityChanged.listen((_) => flush());

    // onConnectivityChanged does not emit the current state on subscribe, so an
    // app opened while already online would never sync a leftover outbox. Flush
    // once now (pushFarmerOutbox self-guards on connectivity).
    await flush();
  }
}
