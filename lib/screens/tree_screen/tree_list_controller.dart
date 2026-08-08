import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';
import 'package:traceability_app/models/get_trees.dart' as gt;
import 'package:traceability_app/screens/tree_screen/tree_detail_screen.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeListController extends GetxController {
  final int plotId;
  final String plotCode;

  TreeListController({required this.plotId, required this.plotCode});

  final _api = TreeApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final searchText = ''.obs;
  final loadingRemote = false.obs;

  final all = <gt.Datum>[].obs;
  final filtered = <gt.Datum>[].obs;
  final pageItems = <gt.Datum>[].obs;

  /// Queued-but-not-uploaded ops for this plot, so the list can show them as
  /// rows (creates) and badge the rows that carry a pending change.
  final pending = PendingIndex.empty.obs;

  final page = 1.obs;
  final pageSize = 10.obs;
  final outboxTotal = 0.obs;
  final syncing = false.obs;
  final syncDone = 0.obs;
  final syncError = RxnString();

  final searchC = TextEditingController();

  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  int get total => filtered.length;
  int get pageCount =>
      (total == 0) ? 1 : ((total + pageSize.value - 1) ~/ pageSize.value);

  bool _isOnlineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return false;
      return list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn != ConnectivityResult.none;
    }
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(TreeApi.startAutoSyncListener());
    _init();
    _listenConnectivity();
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _debounce?.cancel();
    searchC.dispose();
    super.onClose();
  }

  Future<void> _init() async {
    await _refreshOutboxCount();
    await load(initial: true);
    unawaited(_autoSyncIfOnline());
  }

  void _listenConnectivity() {
    _connSub =
        Connectivity().onConnectivityChanged.listen((results) async {
      final online =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      isOfflineView.value = !online;
      await _refreshOutboxCount();
      if (online) unawaited(syncOutboxWithProgress(null, silent: true));
    });
  }

  Future<void> _refreshOutboxCount() async {
    try {
      final n = await _api.getTreeOutboxCount();
      outboxTotal.value = n;
      if (n == 0) {
        syncDone.value = 0;
        syncError.value = null;
        syncing.value = false;
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _autoSyncIfOnline() async {
    final conn = await Connectivity().checkConnectivity();
    if (!_isOnlineFrom(conn)) return;
    await syncOutboxWithProgress(null, silent: true);
  }

  Future<void> load({bool initial = false, String? search}) async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);

    loadingRemote.value = true;
    try {
      final res = await _api.getTreesByPlotIdCached(
        plotId,
        perPage: 2000,
        search: search,
      );
      final list = res.data ?? <gt.Datum>[];

      list.sort((a, b) {
        final ad = a.plantingDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.plantingDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      // Trees added offline live only in the outbox — merge them in so the
      // field user sees what they just recorded, newest first and above the
      // synced rows, each carrying a PendingSyncBadge.
      final idx = (await TreeApi.pendingIndex())
          .whereCreate((op) => pendingBodyInt(op.body, 'plot_id') == plotId);
      pending.value = idx;

      all.value = [
        ...idx.creates.reversed.map(TreeApi.pendingTreeRow),
        ...list,
      ];
      filtered.value = _applyLocalFilter(all, searchC.text.trim());
      page.value = 1;
      _rebuildPage(clamp: true);
    } finally {
      loadingRemote.value = false;
    }
  }

  List<gt.Datum> _applyLocalFilter(List<gt.Datum> src, String q) {
    if (q.isEmpty) return List<gt.Datum>.from(src);
    final qq = q.toLowerCase();
    return src.where((e) {
      final name = (e.treeName ?? '').toLowerCase();
      final species = (e.species ?? '').toLowerCase();
      final qr = (e.qrCode ?? '').toLowerCase();
      final idStr = (e.id?.toString() ?? '').toLowerCase();
      return name.contains(qq) ||
          species.contains(qq) ||
          qr.contains(qq) ||
          idStr == qq;
    }).toList();
  }

  void onSearchChanged(String v) {
    searchText.value = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await load(search: v.trim().isNotEmpty ? v.trim() : null);
      filtered.value = _applyLocalFilter(all.toList(), v.trim());
      page.value = 1;
      _rebuildPage(clamp: true);
    });
  }

  Future<void> refreshData() async {
    await load(
      search: searchC.text.trim().isEmpty ? null : searchC.text.trim(),
    );
    await _refreshOutboxCount();
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
        ? filtered.sublist(start, end)
        : <gt.Datum>[];
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

  int? extractTreeIdFromQr(String raw) {
    final s = raw.trim();
    final numOnly = int.tryParse(s);
    if (numOnly != null) return numOnly;
    if (s.toUpperCase().startsWith('TREE:')) {
      final rest = s.substring(5);
      final first = rest.split('|').first.trim();
      final id = int.tryParse(first);
      if (id != null) return id;
    }
    final m = RegExp(r'(?<!\d)(\d{1,10})(?!\d)').firstMatch(s);
    if (m != null) {
      final id = int.tryParse(m.group(1)!);
      if (id != null) return id;
    }
    return null;
  }

  Future<void> scanQr(BuildContext context) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (_) => const TreeQrScannerSheet(),
    );

    final code = result?.trim();
    if (code == null || code.isEmpty) return;

    final id = extractTreeIdFromQr(code);
    if (id != null) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TreeDetailScreen(treeId: id)),
      );
      if (context.mounted) await refreshData();
      return;
    }

    searchC.text = code;
    await load(search: code);
    if (!context.mounted) return;

    filtered.value = _applyLocalFilter(all.toList(), code);
    page.value = 1;
    _rebuildPage(clamp: true);

    if (filtered.length == 1 && filtered.first.id != null) {
      final onlyId = filtered.first.id!;
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TreeDetailScreen(treeId: onlyId)),
      );
      if (context.mounted) await refreshData();
    }
  }

  Future<bool> confirmDeleteDialog(
      BuildContext context, gt.Datum item) async {
    final isID = language.value == 'id';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isID ? 'Hapus Pohon?' : 'Delete Tree?'),
            content: Text(
              isID
                  ? 'Apakah Anda yakin ingin menghapus pohon ini?\nJika sedang offline, aksi akan disimpan di outbox dan dikirim saat online.'
                  : 'Are you sure you want to delete this tree?\nIf offline, the action will be queued in the outbox and sent when online.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isID ? 'Batal' : 'Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isID ? 'Hapus' : 'Delete'),
              ),
            ],
          ),
        ).then((v) => v ?? false);
  }

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  /// Rows that cannot be opened or deleted yet — see [PendingIndex.blocksActions].
  bool isRowLocked(int? rowId) => pending.value.blocksActions(rowId);

  Future<bool> handleDelete(BuildContext context, gt.Datum item) async {
    if (item.id == null) return false;
    if (pending.value.blocksActions(item.id)) {
      showPendingRowMessage(context, isID: language.value == 'id');
      return false;
    }
    final ok = await confirmDeleteDialog(context, item);
    if (!ok) return false;

    try {
      final res = await _api.deleteTreeOfflineFirst(item.id!);

      all.removeWhere((e) => e.id == item.id);
      filtered.removeWhere((e) => e.id == item.id);
      _rebuildPage(clamp: true);

      await _refreshOutboxCount();

      final text = StringBuffer(tr(res.message));
      if (res.outboxCount > 0) text.write(' • Outbox: ${res.outboxCount}');

      if (!context.mounted) return true;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.toString()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: res.appliedOnline
              ? null
              : SnackBarAction(
                  label: 'SYNC',
                  onPressed: () =>
                      syncOutboxWithProgress(context, silent: false),
                ),
        ),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      final isID = language.value == 'id';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isID ? 'Gagal Menghapus' : 'Delete Failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isID ? 'Tutup' : 'Close'),
            ),
          ],
        ),
      );
      return false;
    }
  }

  Future<void> syncOutboxWithProgress(
    BuildContext? context, {
    required bool silent,
  }) async {
    if (syncing.value) return;

    final conn = await Connectivity().checkConnectivity();
    final online = _isOnlineFrom(conn);
    if (!online) {
      if (!silent && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language.value == 'id'
                  ? 'Tidak ada koneksi internet.'
                  : 'No internet connection.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final before = await _api.getTreeOutboxCount();
    if (before <= 0) {
      await _refreshOutboxCount();
      if (!silent && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language.value == 'id' ? 'Outbox kosong.' : 'Outbox is empty.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    syncing.value = true;
    syncError.value = null;
    syncDone.value = 0;
    outboxTotal.value = before;

    int pushed = 0;
    int after = before;

    try {
      pushed = await _api.pushTreeOutbox();
      after = await _api.getTreeOutboxCount();

      final done = (before - after);
      syncDone.value = done.clamp(0, before);
      outboxTotal.value = after;

      await refreshData();

      if (!silent && context != null && context.mounted) {
        String msg;
        if (after > 0) {
          msg = (language.value == 'id')
              ? 'Sync selesai sebagian: ${before - after}/$before terkirim, sisa $after di queue.'
              : 'Partial sync: ${before - after}/$before sent, $after remaining in queue.';
        } else {
          msg = (language.value == 'id')
              ? 'Sinkron selesai: $before aksi terkirim.'
              : 'Sync completed: $before action(s) sent.';
        }
        if (pushed == 0 && after > 0) {
          msg += (language.value == 'id')
              ? ' (Server tidak memproses batch, cek API/log atau timeout.)'
              : ' (Server did not process a batch, check API/log or timeout.)';
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: after > 0
                ? SnackBarAction(
                    label: 'SYNC',
                    onPressed: () =>
                        syncOutboxWithProgress(context, silent: false),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      syncError.value = e.toString();
      if (!silent && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language.value == 'id'
                  ? 'Gagal sinkron: $e'
                  : 'Sync failed: $e',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      syncing.value = false;
      await _refreshOutboxCount();
    }
  }
}

// ====== QR Scanner Sheet (stays in this file, used by scanQr) ======
class TreeQrScannerSheet extends StatefulWidget {
  const TreeQrScannerSheet({super.key});

  @override
  State<TreeQrScannerSheet> createState() => _TreeQrScannerSheetState();
}

class _TreeQrScannerSheetState extends State<TreeQrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final codes = cap.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .toList();
    if (codes.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(codes.first);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              margin: const EdgeInsets.all(Insets.xl),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flash_on, color: Colors.white),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
