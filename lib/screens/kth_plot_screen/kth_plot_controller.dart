import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as plot_list;
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class KthPlotController extends GetxController {
  KthPlotController({required this.farmerId, this.farmerName});

  final int farmerId;
  final String? farmerName;

  final _api = PlotApi();
  StreamSubscription<dynamic>? _connSub;

  // Observables
  final isOfflineView = false.obs;
  final isSyncing = false.obs;
  final isLoading = true.obs;
  final lastSync = Rxn<DateTime>();
  final plots = <plot_list.Datum>[].obs;
  final error = RxnString();

  /// Queued-but-not-uploaded plot ops for this farmer.
  final pending = PendingIndex.empty.obs;

  @override
  void onInit() {
    super.onInit();
    PlotApi.startAutoSyncListener();
    _load();

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;

      isOfflineView.value = !online;

      if (wasOffline && online) {
        _load();
      }
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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
    final isID = LanguageService.to.isId;
    final months = isID
        ? const [
            'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
            'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
          ]
        : const [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  double? _toDoubleSafe(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  bool _coordInRange(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0.0 && lng == 0.0);
  }

  // ─── Load ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    isLoading.value = true;
    error.value = null;

    try {
      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);

      final res = await _api.getPlotByFarmerIdCached(farmerId);
      final cacheTime = await _api.getPlotByFarmerCacheTime(farmerId);

      lastSync.value = cacheTime;

      // Plots added offline live only in the outbox — show them at the top with
      // a PendingSyncBadge, and badge synced rows that carry a queued change
      // (edit, polygon points or a point photo).
      final idx = await PlotApi.pendingIndex(farmerId: farmerId);
      pending.value = idx;

      plots.assignAll([
        ...idx.creates.reversed.map(PlotApi.pendingPlotRow),
        ...res.data,
      ]);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();

  // ─── Sync ─────────────────────────────────────────────────────────────────

  Future<void> syncNow(BuildContext context) async {
    if (isSyncing.value) return;

    final messenger = ScaffoldMessenger.of(context);

    isSyncing.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      final isOnline = _isOnlineFrom(conn);

      if (!isOnline) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Masih offline. Nyalakan internet lalu coba lagi.'),
          ),
        );
        return;
      }

      final before = await _api.getPlotOutboxCount();
      final pushed = await _api.pushPlotOutbox();
      final after = await _api.getPlotOutboxCount();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
              syncResultMessage(before: before, pushed: pushed, after: after)),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(LanguageService.to.isId
                ? 'Gagal sinkron: $e'
                : 'Sync failed: $e')),
      );
    } finally {
      isSyncing.value = false;
      await _load();
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> goAddPlot(BuildContext context) async {
    final ok = await Navigator.pushNamed(
      context,
      '/kth_add_plot',
      arguments: {'farmerId': farmerId, 'farmerName': farmerName},
    );

    if (ok == true) {
      await _load();
    }
  }

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  /// Rows that cannot be opened/edited/deleted yet — see
  /// [PendingIndex.blocksActions]. Every navigation below funnels through this
  /// so a queued plot (whose id is synthetic) can never be acted on.
  bool isRowLocked(int? rowId) => pending.value.blocksActions(rowId);

  bool _rejectIfLocked(BuildContext context, plot_list.Datum item) {
    if (!isRowLocked(item.id)) return false;
    showPendingRowMessage(context, isID: LanguageService.to.isId);
    return true;
  }

  Future<void> goEditPlot(
      BuildContext context, plot_list.Datum item) async {
    if (_rejectIfLocked(context, item)) return;
    final ok = await Navigator.pushNamed(
      context,
      '/kth_edit_plot',
      arguments: {
        'plot': item,
        'farmerId': farmerId,
        'farmerName': farmerName,
      },
    );

    if (ok == true) {
      await _load();
    }
  }

  Future<void> goPolygon(BuildContext context, plot_list.Datum item) async {
    if (_rejectIfLocked(context, item)) return;
    final isID = LanguageService.to.isId;
    final plotId = item.id;
    if (plotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isID ? 'Plot ID tidak ditemukan' : 'Plot ID not found')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final wkt = await Navigator.pushNamed(
      context,
      '/kth_polygon',
      arguments: {
        'plotId': plotId,
        'polygonWkt': item.polygonWkt,
        'latitude': item.latitude,
        'longitude': item.longitude,
        'plot': item,
      },
    );

    if (wkt == null) return;

    if (wkt is! String) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(isID
                ? 'Format polygon tidak valid'
                : 'Invalid polygon format')),
      );
      return;
    }

    final newWkt = wkt.trim();
    if (newWkt.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(isID ? 'Polygon kosong' : 'Empty polygon')),
      );
      return;
    }

    final lat = _toDoubleSafe(item.latitude);
    final lng = _toDoubleSafe(item.longitude);

    if (lat == null || lng == null || !_coordInRange(lat, lng)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isID
                ? 'Latitude/Longitude plot tidak valid, tidak bisa menyimpan polygon.'
                : 'Plot latitude/longitude is invalid, cannot save polygon.',
          ),
        ),
      );
      return;
    }

    try {
      final res = await _api.editPlotOfflineFirst(
        id: plotId,
        plotName: (item.plotName ?? '').toString(),
        landArea: item.landArea,
        numberOfPlants: item.numberOfPlants ?? 0,
        latitude: lat,
        longitude: lng,
        farmerId: item.farmerId ?? farmerId,
        polygon: newWkt,
      );

      messenger.showSnackBar(SnackBar(content: Text(tr(res.message))));
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(isID
                ? 'Gagal simpan polygon: $e'
                : 'Failed to save polygon: $e')),
      );
    }
  }

  Future<void> goSaprodi(BuildContext context, plot_list.Datum item) async {
    if (_rejectIfLocked(context, item)) return;
    final plotId = item.id;
    if (plotId == null) {
      final isID = LanguageService.to.isId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isID ? 'Plot ID tidak ditemukan' : 'Plot ID not found')),
      );
      return;
    }
    await Navigator.pushNamed(context, '/saprodi', arguments: plotId);
  }

  Future<void> confirmDelete(
      BuildContext context, plot_list.Datum item) async {
    if (_rejectIfLocked(context, item)) return;
    final isID = LanguageService.to.isId;
    final plotId = item.id;
    if (plotId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isID ? 'Hapus Plot?' : 'Delete Plot?'),
            content: Text(
              isID
                  ? 'Apakah Anda yakin ingin menghapus plot ini?\n'
                      'Jika sedang offline, aksi akan disimpan di outbox dan dikirim saat online.'
                  : 'Are you sure you want to delete this plot?\n'
                      'If offline, the action will be queued and sent when online.',
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

    if (!ok) return;

    try {
      final res = await _api.deletePlotOfflineFirst(plotId);
      messenger.showSnackBar(SnackBar(content: Text(tr(res.message))));
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                isID ? 'Gagal hapus: $e' : 'Failed to delete: $e')),
      );
    }
  }
}
