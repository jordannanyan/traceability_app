import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_farmer_id.dart';
import 'package:traceability_app/screens/farmer_setoran_screen/setoran_screen_widget/purchasing_mothly_chart_widget.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class FarmerSetoranController extends GetxController {
  final _api = PurchasingApi();

  final language     = LanguageService.to.language;
  final isOfflineView = false.obs;
  final lastSync     = Rxn<DateTime>();
  final syncing      = false.obs;
  final isLoading    = false.obs;
  final error        = RxnString();
  final items        = <Datum>[].obs;
  final metric       = PurchasingMetric.kg.obs;

  int? farmerId;

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    PurchasingApi.startAutoSyncListener();
    load();
    _connSub = Connectivity().onConnectivityChanged.listen(_onConnChanged);
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

  Future<void> _onConnChanged(dynamic conn) async {
    final online = _isOnlineFrom(conn);
    final wasOffline = isOfflineView.value;
    isOfflineView.value = !online;
    if (wasOffline && online) await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      farmerId = prefs.getInt('id');

      if (farmerId == null || farmerId == 0) {
        throw Exception('Farmer ID tidak ditemukan. Silakan login ulang.');
      }

      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final res = await _api.getPurchasingByFarmerIdCached(farmerId!);
      lastSync.value = await _api.getPurchasingCacheTime(farmerId!);

      final loaded = (res.data ?? <Datum>[])
          .where((d) => d.date != null)
          .toList()
        ..sort((a, b) => (a.date!).compareTo(b.date!));

      items.value = loaded;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncNow(BuildContext context) async {
    if (syncing.value) return;
    syncing.value = true;
    final isID = language.value == 'id';
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!_isOnlineFrom(conn)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  isID
                      ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                      : 'Still offline. Turn on internet and try again.')));
        }
        return;
      }

      final before = await _api.getPurchasingStatusOutboxCount();
      final pushed = await _api.pushPurchasingStatusOutbox();
      final after = await _api.getPurchasingStatusOutboxCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              syncResultMessage(before: before, pushed: pushed, after: after)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isID ? 'Gagal sinkron: $e' : 'Sync failed: $e')));
      }
    } finally {
      syncing.value = false;
      await load();
    }
  }

  String fmtLastSync() {
    final d = lastSync.value;
    if (d == null) return '-';
    const idMonths = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'
    ];
    const enMonths = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final months = language.value == 'id' ? idMonths : enMonths;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
