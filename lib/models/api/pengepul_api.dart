import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/pengepul_model.dart';
import 'package:traceability_app/utils/utils.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

class PengepulApi {
  late final Dio _dio;

  // ===== Cache keys =====
  static String _cacheKey(int kthId) => 'cache_pengepul_kth_$kthId';
  static String _cacheTsKey(int kthId) => 'cache_pengepul_kth_${kthId}_ts';

  PengepulApi() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl, // ganti ke konstanta app
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

  // ========= Connectivity helper (robust) =========
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ========= Auth header =========
  Future<Options> _auth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) throw UnauthorizedException('Token is missing. Please log in again.');
    return Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
  }

  // ========= Cache helpers =========
  Future<void> _saveCache(int kthId, dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey(kthId), jsonEncode(data));
    await p.setInt(_cacheTsKey(kthId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<PengepulModel?> _loadCacheModel(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    return pengepulModelFromJson(raw);
  }

  Future<DateTime?> getPengepulCacheTime(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final ts = p.getInt(_cacheTsKey(kthId));
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  // ========= API ONLINE (tetap ada untuk kompat) =========
  Future<PengepulModel> fetchPengepulData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt('id') ?? 0;
      if (id == 0) throw UnauthorizedException('User ID missing. Please log in again.');

      final resp = await _dio.get('/kth/$id', options: await _auth());
      if (resp.statusCode == 200) {
        return pengepulModelFromJson(jsonEncode(resp.data));
      }
      throw Exception(_extractErrorMessage(resp.data) ?? 'Unknown server error');
    } on DioException catch (e) {
      // 401/HTML error → unauthorized
      if (e.response?.statusCode == 401 ||
          (e.response?.data is String && (e.response?.data as String).contains('<!DOCTYPE html>'))) {
        throw UnauthorizedException(_extractErrorMessage(e.response?.data) ?? 'Authentication failed');
      }
      if (e.response != null) {
        throw Exception(_extractErrorMessage(e.response?.data) ?? 'Server error occurred');
      }
      throw Exception('Connection error: ${e.message}');
    }
  }

// ========= API CACHED-FIRST (OFFLINE-FIRST) =========
Future<PengepulModel> fetchPengepulDataCached() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt('id') ?? 0;
  if (id == 0) throw UnauthorizedException('User ID missing. Please log in again.');

  final online = await _isOnline();

  if (online) {
    try {
      final resp = await _dio.get('/kth/$id', options: await _auth());
      if (resp.statusCode == 200) {
        await _saveCache(id, resp.data);
        return pengepulModelFromJson(jsonEncode(resp.data));
      }
      // server non-200 → coba cache
      final cached = await _loadCacheModel(id);
      if (cached != null) return cached;

      // tidak ada cache: kembalikan model kosong (UI bisa cek id==null)
      return PengepulModel();
    } on UnauthorizedException {
      rethrow; // biar UI bisa force re-login
    } catch (_) {
      final cached = await _loadCacheModel(id);
      if (cached != null) return cached;
      return PengepulModel(); // kosong jika tak ada cache
    }
  } else {
    final cached = await _loadCacheModel(id);
    if (cached != null) return cached;
    return PengepulModel(); // offline + no cache → kosong
  }
}

  // ========= Error extractor =========
  String? _extractErrorMessage(dynamic data) {
    try {
      if (data == null) return null;
      if (data is String) return data;
      if (data is Map) return data['message'] as String?;
      return data.toString();
    } catch (_) {
      return null;
    }
  }
}

// Custom exception for unauthorized access
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}
