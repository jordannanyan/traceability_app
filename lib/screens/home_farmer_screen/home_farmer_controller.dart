import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/sync_service.dart';

class HomeFarmerController extends GetxController {
  final language = LanguageService.to.language;
  final farmerName = ''.obs;
  final isOfflineView = false.obs;
  final isLoading = true.obs;

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    _init();
    _connSub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    // Start every module's outbox sync + flush anything queued offline, so a
    // reconnect (or opening the app already online) pushes all pending data.
    SyncService.startAll();
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    await refresh();
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

  Future<void> _onConnectivity(dynamic conn) async {
    final online = _isOnlineFrom(conn);
    isOfflineView.value = !online;
    if (online) await refresh();
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      farmerName.value = prefs.getString('name') ?? '';
    } finally {
      isLoading.value = false;
    }
  }
}
