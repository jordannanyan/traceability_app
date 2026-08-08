import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/selling_api.dart';
import 'package:traceability_app/models/get_selling_by_kth_id.dart' as model;
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class SellingController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _api = SellingApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final items = <model.Datum>[].obs;
  final error = RxnString();
  final lastSync = Rxn<DateTime>();
  final isSyncing = false.obs;

  /// Kenapa daftar ini berisi apa yang ditampilkan.
  final refreshOutcome = RefreshOutcome.fresh.obs;

  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  int? _kthId;
  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    SellingApi.startAutoSyncListener();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    fadeAnimation =
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut);
    animationController.forward();

    _bootConnectivity();
    load();

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) load();
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    animationController.dispose();
    super.onClose();
  }

  Future<void> _bootConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);
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

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      _kthId = prefs.getInt('kth_id') ??
          prefs.getInt('kthId') ??
          prefs.getInt('id') ??
          0;
      if (_kthId == 0) {
        error.value = language.value == 'id'
            ? 'KTH ID tidak ditemukan. Silakan login ulang.'
            : 'KTH ID not found. Please log in again.';
        return;
      }

      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final result = await _api.getSellingByKthIdCached(_kthId!);
      refreshOutcome.value = result.outcome;
      lastSync.value = await _api.getSellingByKthCacheTime(_kthId!);
      items.assignAll(result.data.data ?? <model.Datum>[]);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncNow(BuildContext context) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      final isOnline = _isOnlineFrom(conn);
      if (!isOnline) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              language.value == 'id'
                  ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                  : 'Still offline. Turn on internet and try again.',
            ),
          ));
        }
        return;
      }

      final before = await _api.getSellingOutboxCount();
      final pushed = await _api.pushSellingOutbox();
      final after = await _api.getSellingOutboxCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              syncResultMessage(before: before, pushed: pushed, after: after)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync error: $e')));
      }
    } finally {
      isSyncing.value = false;
      await load();
    }
  }

  String fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    const idMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = language.value == 'id' ? idMonths : enMonths;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${m[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
