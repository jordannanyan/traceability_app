import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/screens/widgets/stale_data_banner.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PlotListFarmerWidget extends StatefulWidget {
  /// If null, it will read `id` from SharedPreferences (set on login as farmer).
  final int? farmerId;

  /// Optional callbacks
  final void Function(int index, Datum item)? onTapPlot;
  final void Function(int index, Datum item)? onViewSaprodi;
  final void Function(int index, Datum item)? onEditPlot;

  const PlotListFarmerWidget({
    super.key,
    this.farmerId,
    this.onTapPlot,
    this.onViewSaprodi,
    this.onEditPlot,
  });

  @override
  State<PlotListFarmerWidget> createState() => _PlotListFarmerWidgetState();
}

class _PlotListFarmerWidgetState extends State<PlotListFarmerWidget> {
  late Future<List<Datum>> _future;
  final _api = PlotApi();
  int? _farmerId;
  DateTime? _lastSync;

  /// Queued-but-not-uploaded plot ops, refreshed together with [_load].
  PendingIndex _pending = PendingIndex.empty;

  /// Kenapa daftar ini berisi apa yang ditampilkan.
  RefreshOutcome _refreshOutcome = RefreshOutcome.fresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    final isID = LanguageService.to.isId;
    final months = isID
        ? const ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']
        : const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<List<Datum>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _farmerId = widget.farmerId ?? (prefs.getInt('id') ?? 0);
    if (_farmerId == null || _farmerId == 0) {
      final isID = LanguageService.to.isId;
      throw Exception(isID
          ? 'Farmer ID tidak ditemukan. Silakan login ulang.'
          : 'Farmer ID not found. Please log in again.');
    }

    // cached-first → tetap tampil saat offline, auto-refresh cache saat online
    final result = await _api.getPlotByFarmerIdCached(_farmerId!);
    _refreshOutcome = result.outcome;
    final res = result.data;
    _lastSync = await _api.getPlotByFarmerCacheTime(_farmerId!);

    // Plots still sitting in the outbox are merged in so an offline edit (or a
    // plot added on this device) is visible here, marked with a badge.
    _pending = await PlotApi.pendingIndex(farmerId: _farmerId!);

    return [
      ..._pending.creates.reversed.map(PlotApi.pendingPlotRow),
      ...res.data,
    ];
  }

  /// Shows the "waiting to sync" message and swallows the action for rows that
  /// have no usable server record yet.
  bool _rejectIfLocked(BuildContext context, Datum item, bool isID) {
    if (!_pending.blocksActions(item.id)) return false;
    showPendingRowMessage(context, isID: isID);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return FutureBuilder<List<Datum>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              children: [
                Text(
                  snap.error.toString(),
                  style: ThemeTextStyle.textStyleForthBold.copyWith(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: Text(isID ? 'Coba Lagi' : 'Retry'),
                ),
              ],
            ),
          );
        }

        final items = snap.data ?? const <Datum>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // tetap tampilkan last sync agar user tahu kapan cache terakhir
                Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      isID
                          ? 'Terakhir sinkron: ${_fmtLastSync(_lastSync)}'
                          : 'Last sync: ${_fmtLastSync(_lastSync)}',
                      style: ThemeTextStyle.textStyleForthBold.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(isID ? 'Belum ada data lahan.' : 'No plot data yet.',
                    style: ThemeTextStyle.textStyleThird),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: StaleDataBanner(
                outcome: _refreshOutcome,
                isID: isID,
                onRetry: () => setState(() => _future = _load()),
              ),
            ),

            // small last-sync chip
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    isID
                        ? 'Terakhir sinkron: ${_fmtLastSync(_lastSync)}'
                        : 'Last sync: ${_fmtLastSync(_lastSync)}',
                    style: ThemeTextStyle.textStyleForthBold.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 490, // tinggi kartu agar ListView punya ukuran
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.82,
                    child: _buildPlotCard(context, item, index, isID),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
    });
  }

  Widget _buildPlotCard(BuildContext context, Datum item, int index, bool isID) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () {
          if (_rejectIfLocked(context, item, isID)) return;
          widget.onTapPlot?.call(index, item);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(item, isID),
                const SizedBox(height: 16),
                _buildDivider(),
                const SizedBox(height: 16),
                _buildInfoSection(isID ? 'Informasi Plot' : 'Plot Info', [
                  _buildRow(Icons.agriculture,
                      isID ? 'Nama Plot' : 'Plot Name', item.plotName ?? '-'),
                  _buildRow(Icons.area_chart,
                      isID ? 'Luas Lahan' : 'Land Area', _fmtArea(item.landArea)),
                  _buildRow(
                      Icons.eco,
                      isID ? 'Jumlah Tanaman' : 'Number of Plants',
                      _fmtPlants(item.numberOfPlants, isID)),
                  _buildRow(
                      Icons.location_on,
                      isID ? 'Koordinat' : 'Coordinates',
                      _fmtLatLng(item.latitude, item.longitude)),
                ]),
                const SizedBox(height: 16),
                _buildActionButtons(context, item, index, isID),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Datum item, bool isID) {
    final pendingKind = _pending.kindFor(item.id);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ThemeColor.darkestGreen, ThemeColor.darkestGreen.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: [
              BoxShadow(
                color: ThemeColor.darkestGreen.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.agriculture, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.plotName ?? '-',
                style: ThemeTextStyle.textStyleForthBold.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeColor.darkestGreen,
                    ),
              ),
              if (pendingKind != null) ...[
                const SizedBox(height: Insets.xs),
                PendingSyncBadge(kind: pendingKind, isID: isID),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.grey.withValues(alpha: 0.3), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ThemeColor.darkestGreen,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)),
      ],
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: ThemeColor.darkestGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 13, color: Colors.grey.shade800),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Datum item, int index, bool isID) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (_rejectIfLocked(context, item, isID)) return;
              widget.onViewSaprodi?.call(index, item);
            },
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(isID ? 'Lihat Saprodi' : 'View Saprodi',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThemeColor.darkestGreen,
              side: BorderSide(color: ThemeColor.darkestGreen.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (_rejectIfLocked(context, item, isID)) return;
              widget.onEditPlot?.call(index, item);
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.darkestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  // --- helpers ---

  String _fmtArea(String? area) {
    if (area == null || area.trim().isEmpty) return '-';
    return area.toLowerCase().contains('ha') ? area : '$area Ha';
  }

  String _fmtPlants(int? n, bool isID) {
    if (n == null) return '-';
    return isID ? '$n Tanaman' : '$n Plants';
  }

  String _fmtLatLng(String? lat, String? lng) {
    final a = (lat == null || lat.isEmpty) ? '-' : lat;
    final b = (lng == null || lng.isEmpty) ? '-' : lng;
    return '$a, $b';
  }
}
