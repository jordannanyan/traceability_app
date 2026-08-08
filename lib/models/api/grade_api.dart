import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/get_grade.dart';
import 'package:traceability_app/utils/utils.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

class GradeApi {
  late final Dio _dio;

  // ===== Cache keys =====
  static const String _cacheKey = 'cache_grades_v1';
  static const String _cacheTsKey = 'cache_grades_v1_ts';

  GradeApi() {
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
          onRequest: (o, h) {
            debugPrint('➡️ ${o.method} ${o.baseUrl}${o.path}');
            h.next(o);
          },
          onResponse: (r, h) {
            debugPrint('✅ ${r.statusCode} ${r.requestOptions.method} ${r.requestOptions.path}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint('❌ DioError ${e.type} on ${e.requestOptions.method} ${e.requestOptions.uri} : ${e.message}');
            h.next(e);
          },
        ),
      );
    }
  }

  // ========= Connectivity (robust) =========
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ========= Auth =========
  Future<Options> _auth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      throw Exception('Token not found. Please log in again.');
    }
    return Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
  }

  // ========= Cache helpers =========
  Future<void> _saveCache(dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey, jsonEncode(data));
    await p.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<GetGrade>?> _loadCacheModel() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    return getGradeFromJson(raw);
  }

  Future<DateTime?> getGradesCacheTime() async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheTsKey);
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ========= API ONLINE (tetap ada) =========
  Future<List<GetGrade>> getGrades() async {
    try {
      final resp = await _dio.get('/grades', options: await _auth());
      if (resp.statusCode == 200) {
        return getGradeFromJson(jsonEncode(resp.data));
      }
      throw Exception(resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch grade data') : 'Failed to fetch grade data');
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

  // ========= API CACHED-FIRST (OFFLINE-FIRST) =========
  Future<List<GetGrade>> getGradesCached() async {
    final online = await _isOnline();

    if (online) {
      try {
        final resp = await _dio.get('/grades', options: await _auth());
        if (resp.statusCode == 200) {
          await _saveCache(resp.data);
          return getGradeFromJson(jsonEncode(resp.data));
        }
        // server non-200 → coba cache
        final cached = await _loadCacheModel();
        if (cached != null) return cached;
        throw Exception(resp.data is Map ? (resp.data['message'] ?? 'Failed to fetch grade data') : 'Failed to fetch grade data');
      } catch (_) {
        final cached = await _loadCacheModel();
        if (cached != null) return cached;
        // tidak ada cache sama sekali → kosong agar UI tetap jalan
        return <GetGrade>[];
      }
    } else {
      final cached = await _loadCacheModel();
      if (cached != null) return cached;
      // offline + belum ada cache → kosong
      return <GetGrade>[];
    }
  }
}
