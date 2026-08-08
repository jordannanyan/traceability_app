import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart' as pm;
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class PurchasingController extends GetxController {
  final _api = PurchasingApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final data = Rxn<pm.GetPurchasingByKthId>();
  final error = RxnString();
  final lastSync = Rxn<DateTime>();
  final isSyncing = false.obs;

  /// Queued-but-not-uploaded purchasing ops (CRUD + status changes).
  final pending = PendingIndex.empty.obs;

  int? _kthId;
  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    PurchasingApi.startAutoSyncListener();
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

      final res = await _api.getPurchasingByKthIdCached(_kthId!);
      lastSync.value = await _api.getPurchasingByKthCacheTime(_kthId!);

      // Purchases with a queued edit or status change keep their row and get a
      // PendingSyncBadge; anything queued as a create (rare — the add screen
      // writes online only) is merged in on top so it is not invisible.
      final idx = await PurchasingApi.pendingIndex();
      pending.value = idx;

      data.value = pm.GetPurchasingByKthId(
        status: res.status,
        data: [
          ...idx.creates.reversed.map(PurchasingApi.pendingPurchasingRow),
          ...res.data,
        ],
      );
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

      final before = await _api.getPurchasingStatusOutboxCount() +
          await _api.getPurchasingCrudOutboxCount();
      final pushedStatus = await _api.pushPurchasingStatusOutbox();
      final pushedCrud = await _api.pushPurchasingOutbox();
      final pushed = pushedStatus + pushedCrud;
      final after = await _api.getPurchasingStatusOutboxCount() +
          await _api.getPurchasingCrudOutboxCount();

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

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  /// Rows that cannot be opened/edited yet — see [PendingIndex.blocksActions].
  bool isRowLocked(int? rowId) => pending.value.blocksActions(rowId);

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
