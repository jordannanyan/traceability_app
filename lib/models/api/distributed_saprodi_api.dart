import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/get_distributed_saprodi_by_plot_id.dart';
import 'package:traceability_app/utils/utils.dart';

class DistributedSaprodiApi {
  late final Dio _dio;

  // Cache keys per plot
  static String _cacheKey(int plotId) => 'cache_distributed_saprodi_plot_$plotId';
  static String _cacheTsKey(int plotId) => 'cache_distributed_saprodi_plot_${plotId}_ts';

  DistributedSaprodiApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
        responseType: ResponseType.json,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) { debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}'); h.next(o); },
          onResponse: (r, h) { debugPrint('✅ ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.path}'); h.next(r); },
          onError: (e, h) { debugPrint('❌ DioError ${e.type} on ${e.requestOptions.method} ${e.requestOptions.uri} : ${e.message}'); h.next(e); },
        ),
      );
    }
  }

  // ---------- connectivity (robust) ----------
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ---------- auth ----------
  Future<Options> _auth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      throw Exception('Token not found. Please log in again.');
    }
    return Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
  }

  // ---------- cache helpers ----------
  Future<void> _saveCache(int plotId, dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey(plotId), jsonEncode(data));
    await p.setInt(_cacheTsKey(plotId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetDistributedSaprodiByPlotId?> _loadCacheModel(int plotId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey(plotId));
    if (raw == null || raw.isEmpty) return null;
    return getDistributedSaprodiByPlotIdFromJson(raw);
  }

  Future<DateTime?> getDistributedSaprodiCacheTime(int plotId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheTsKey(plotId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  static GetDistributedSaprodiByPlotId _empty() =>
      GetDistributedSaprodiByPlotId(status: 'no-data', data: []);

  // ---------- ONLINE (tetap ada; sekaligus refresh cache) ----------
  Future<GetDistributedSaprodiByPlotId> getDistributedSaprodiByPlotId(int plotId) async {
    try {
      final resp = await _dio.get('/distributed-sapropdi/plot/$plotId', options: await _auth());
      if (resp.statusCode == 200) {
        await _saveCache(plotId, resp.data);
        return getDistributedSaprodiByPlotIdFromJson(jsonEncode(resp.data));
      }
      // 404 = belum ada data saprodi untuk plot ini, bukan error
      if (resp.statusCode == 404) return _empty();
      throw Exception(resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch distributed saprodi data') : 'Failed to fetch distributed saprodi data');
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        throw Exception(data is Map ? (data['message'] ?? 'Server error') : 'Server error');
      } else {
        throw Exception('Connection error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // ---------- CACHED-FIRST (OFFLINE-FIRST) ----------
  Future<GetDistributedSaprodiByPlotId> getDistributedSaprodiByPlotIdCached(int plotId) async {
    final online = await _isOnline();

    if (online) {
      try {
        final resp = await _dio.get('/distributed-sapropdi/plot/$plotId', options: await _auth());
        if (resp.statusCode == 200) {
          await _saveCache(plotId, resp.data);
          return getDistributedSaprodiByPlotIdFromJson(jsonEncode(resp.data));
        }
        // 404 = belum ada data saprodi untuk plot ini, bukan error
        if (resp.statusCode == 404) return _empty();
        // status lain → coba cache
        final cached = await _loadCacheModel(plotId);
        if (cached != null) return cached;
        throw Exception(resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch distributed saprodi data') : 'Failed to fetch distributed saprodi data');
      } catch (_) {
        final cached = await _loadCacheModel(plotId);
        if (cached != null) return cached;
        throw Exception('online-error-no-cache');
      }
    } else {
      final cached = await _loadCacheModel(plotId);
      if (cached != null) return cached;
      throw Exception('offline-no-cache');
    }
  }
}
