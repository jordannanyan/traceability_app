import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/kth_api.dart';
import 'package:traceability_app/models/get_kth_by_id.dart';
import 'package:traceability_app/services/language_service.dart';

class KthSettingController extends GetxController {
  final _api = KthApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final data = Rxn<Data>();
  final error = RxnString();
  final lastSync = Rxn<DateTime>();

  int _kthId = 0;
  bool _didAutoLogout = false;
  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    load();
    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) async {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) {
        await load();
      }
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  bool _isOnlineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return false;
      return list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn != ConnectivityResult.none;
    }
  }

  String fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = language.value == 'id' ? id : en;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${m[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      _kthId = prefs.getInt('id') ?? 0;
      if (_kthId == 0) {
        throw Exception(
          language.value == 'id'
              ? 'Partner ID tidak ditemukan. Silakan login ulang.'
              : 'Partner ID not found. Please log in again.',
        );
      }

      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final res = await _api.getKthByIdCached(_kthId);
      lastSync.value = await _api.getKthCacheTime(_kthId);
      data.value = res.data;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() async => load();

  Future<void> openLanguage(BuildContext context) async {
    final changed = await Navigator.pushNamed(context, '/language');
    if (changed == true) {
      await load();
    }
  }

  Future<void> forceLogoutNow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.deleteAll();
    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login-koperasi', (route) => false);
    }
  }

  void scheduleAutoLogoutIfNeeded(Object? err, BuildContext context) {
    if (_didAutoLogout) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLogoutOnCriticalError(err, context);
    });
  }

  Future<void> _autoLogoutOnCriticalError(
      Object? err, BuildContext context) async {
    if (_didAutoLogout) return;

    final msg = (err ?? '').toString().toLowerCase();
    final bool shouldLogout =
        msg.contains('online-error-no-cache') ||
        msg.contains('partner id tidak ditemukan') ||
        msg.contains('partner id not found') ||
        msg.contains('unauthorized') ||
        msg.contains('401') ||
        (msg.contains('token') && msg.contains('expired'));

    if (!shouldLogout) return;

    _didAutoLogout = true;
    final isID = language.value == 'id';

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.deleteAll();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isID
              ? 'Sesi berakhir. Silakan login ulang.'
              : 'Session expired. Please log in again.',
        ),
      ),
    );

    Navigator.of(context)
        .pushNamedAndRemoveUntil('/login-koperasi', (route) => false);
  }

  Future<void> logout(BuildContext context) async {
    final isID = language.value == 'id';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isID ? 'Keluar Akun' : 'Log out'),
        content: Text(
          isID
              ? 'Anda akan keluar dari akun Partner ini.'
              : 'You will be logged out from this Partner account.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Get.deleteAll();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login-koperasi');
              }
            },
            child: Text(isID ? 'Iya' : 'Yes'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isID ? 'Batal' : 'Cancel'),
          ),
        ],
      ),
    );
  }
}
