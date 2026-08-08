import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/warehouse_api.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class GudangController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _api = WarehouseApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final items = <wh.Datum>[].obs;
  final error = RxnString();
  final lastSync = Rxn<DateTime>();
  final isSyncing = false.obs;

  /// Queued-but-not-uploaded warehouse edits.
  final pending = PendingIndex.empty.obs;

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    WarehouseApi.startAutoSyncListener();
    _initAnim();
    load();
    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) async {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) await load();
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    animationController.dispose();
    super.onClose();
  }

  void _initAnim() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );
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

  String fmtDate(DateTime d) {
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final arr = language.value == 'id' ? id : en;
    return '${d.day.toString().padLeft(2, '0')} ${arr[d.month - 1]} ${d.year}';
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final kthId =
          prefs.getInt('kth_id') ??
          prefs.getInt('kthId') ??
          prefs.getInt('id') ??
          0;

      if (kthId == 0) {
        throw Exception(
          language.value == 'id'
              ? 'Partner ID tidak ditemukan. Silakan login ulang.'
              : 'Partner ID not found. Please log in again.',
        );
      }

      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final res = await _api.getWarehouseByKthIdCached(kthId);
      lastSync.value = await _api.getWarehouseByKthCacheTime(kthId);
      items.value = res.data ?? [];

      // A warehouse edited offline still shows its old (cached) values, so the
      // row gets a PendingSyncBadge to explain why.
      pending.value = await WarehouseApi.pendingIndex();
      animationController.forward(from: 0);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncNow(BuildContext context) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    final isID = language.value == 'id';
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!_isOnlineFrom(conn)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              isID
                  ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                  : 'Still offline. Turn on internet and try again.',
            ),
          ));
        }
        return;
      }
      final before = await _api.getWarehouseOutboxCount();
      final pushed = await _api.pushWarehouseOutbox();
      final after = await _api.getWarehouseOutboxCount();
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
            (isID ? 'Gagal sinkron: ' : 'Sync failed: ') + e.toString(),
          ),
        ));
      }
    } finally {
      isSyncing.value = false;
      await load();
    }
  }
}
