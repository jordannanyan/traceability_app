import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/tree_monitoring_api.dart';
import 'package:traceability_app/models/tree_monitoring.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class TreeMonitoringController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final int treeId;
  TreeMonitoringController({required this.treeId});

  final _api = TreeMonitoringApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final syncing = false.obs;
  final lastSync = Rxn<DateTime>();
  final isLoading = false.obs;
  final error = RxnString();

  final all = <TreeMonitoring>[].obs;
  final pageItems = <TreeMonitoring>[].obs;
  final deleting = <int>[].obs;

  /// Queued-but-not-uploaded monitoring ops for this tree.
  final pending = PendingIndex.empty.obs;

  /// Kenapa daftar ini berisi apa yang ditampilkan.
  final refreshOutcome = RefreshOutcome.fresh.obs;

  final page = 1.obs;
  final pageSize = 10.obs;

  late final AnimationController animController;
  late final Animation<double> fadeAnimation;

  StreamSubscription<dynamic>? _connSub;

  int get total => all.length;
  int get pageCount =>
      (total == 0) ? 1 : ((total + pageSize.value - 1) ~/ pageSize.value);

  @override
  void onInit() {
    super.onInit();
    TreeMonitoringApi.startAutoSyncListener();

    animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    fadeAnimation =
        CurvedAnimation(parent: animController, curve: Curves.easeInOut);
    animController.forward();

    _bootConnectivity();
    load();

    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) async {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) load();
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    animController.dispose();
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
      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final result = await _api.listByTreeCached(
        treeId: treeId,
        page: 1,
        perPage: 100,
      );
      refreshOutcome.value = result.outcome;
      final pageRes = result.data;
      lastSync.value = await _api.getListCacheTime(
        treeId,
        page: 1,
        perPage: 100,
      );

      final items = [...(pageRes.data)];
      items.sort((a, b) {
        final ad = a.measuredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.measuredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final c = bd.compareTo(ad);
        if (c != 0) return c;
        final ai = a.id ?? 0, bi = b.id ?? 0;
        return bi.compareTo(ai);
      });

      // Monitorings recorded offline exist only in the outbox — show them at
      // the top (newest first) with a PendingSyncBadge instead of hiding them
      // until the queue drains.
      final idx = await TreeMonitoringApi.pendingIndex(treeId: treeId);
      pending.value = idx;

      all.value = [
        ...idx.creates.reversed.map(
          (op) => TreeMonitoringApi.pendingMonitoringRow(op, treeId: treeId),
        ),
        ...items,
      ];
      page.value = 1;
      _rebuildPage(clamp: true);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _rebuildPage({bool clamp = true}) {
    if (clamp) {
      if (page.value < 1) page.value = 1;
      if (page.value > pageCount) page.value = pageCount;
    }
    final start = (page.value - 1) * pageSize.value;
    final end = (start + pageSize.value) > total
        ? total
        : (start + pageSize.value);
    pageItems.value = (start >= 0 && start < total)
        ? all.sublist(start, end)
        : <TreeMonitoring>[];
  }

  void goPrev() {
    if (page.value <= 1) return;
    page.value--;
    _rebuildPage();
  }

  void goNext() {
    if (page.value >= pageCount) return;
    page.value++;
    _rebuildPage();
  }

  void setPageSize(int n) {
    pageSize.value = n;
    page.value = 1;
    _rebuildPage();
  }

  Future<void> syncNow(BuildContext context) async {
    if (syncing.value) return;
    syncing.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!_isOnlineFrom(conn)) {
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

      final before = await _api.getOutboxCount();
      final pushed = await _api.pushOutbox();
      final after = await _api.getOutboxCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              syncResultMessage(before: before, pushed: pushed, after: after)),
        ));
      }
      await load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync error: $e')));
      }
    } finally {
      syncing.value = false;
    }
  }

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  Future<void> deleteMonitoring(
      BuildContext context, int monitoringId) async {
    if (deleting.contains(monitoringId)) return;

    if (pending.value.blocksActions(monitoringId)) {
      showPendingRowMessage(context, isID: language.value == 'id');
      return;
    }

    deleting.add(monitoringId);
    try {
      final res = await _api.deleteOfflineFirst(monitoringId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(res.message))));
      }
      await load();
    } catch (_) {
      // ignore
    } finally {
      deleting.remove(monitoringId);
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
