import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/get_commodities.dart';
import 'package:traceability_app/utils/utils.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

class CommoditiesApi {
  late final Dio _dio;

  // Cache keys (global list)
  static const String _cacheKey   = 'cache_commodities_v1';
  static const String _cacheTsKey = 'cache_commodities_v1_ts';

  CommoditiesApi() {
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

    _dio.interceptors.add(SessionMonitor.watchdog());

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) { debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}'); h.next(o); },
          onResponse: (r, h) { debugPrint('✅ ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.path}'); h.next(r); },
          onError: (e, h) { debugPrint('❌ DioError ${e.type} on ${e.requestOptions.method} ${e.requestOptions.uri}: ${e.message}'); h.next(e); },
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
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token') ?? '';
    if (token.isEmpty) {
      throw Exception('Token not found. Please log in again.');
    }
    return Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
  }

  // ---------- cache helpers ----------
  Future<void> _saveCache(dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey, jsonEncode(data));
    await p.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<GetCommodities?> _loadCacheModel() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    return getCommoditiesFromJson(raw);
  }

  Future<DateTime?> getCommoditiesCacheTime() async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheTsKey);
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ---------- ONLINE (tetap ada) ----------
  Future<GetCommodities> getCommodities() async {
    try {
      final resp = await _dio.get('/commodities', options: await _auth());
      if (resp.statusCode == 200) {
        return getCommoditiesFromJson(jsonEncode(resp.data));
      }
      throw Exception(
        resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch commodities')
                         : 'Failed to fetch commodities',
      );
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
  Future<GetCommodities> getCommoditiesCached() async {
    final online = await _isOnline();

    if (online) {
      try {
        final resp = await _dio.get('/commodities', options: await _auth());
        if (resp.statusCode == 200) {
          await _saveCache(resp.data);
          return getCommoditiesFromJson(jsonEncode(resp.data));
        }
        // server non-200 → coba cache
        final cached = await _loadCacheModel();
        if (cached != null) return cached;
        throw Exception(
          resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch commodities')
                           : 'Failed to fetch commodities',
        );
      } catch (_) {
        final cached = await _loadCacheModel();
        if (cached != null) return cached;
        // tidak ada cache → objek kosong
        return getCommoditiesFromJson(jsonEncode({'data': []}));
      }
    } else {
      final cached = await _loadCacheModel();
      if (cached != null) return cached;
      // offline + no cache → objek kosong
      return getCommoditiesFromJson(jsonEncode({'data': []}));
    }
  }
}
