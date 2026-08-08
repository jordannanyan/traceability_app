import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_farmer_id.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/screens/widgets/stale_data_banner.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PurchasingListWidget extends StatefulWidget {
  final int? farmerId; // optional override, otherwise read from SharedPreferences
  const PurchasingListWidget({super.key, this.farmerId});

  @override
  State<PurchasingListWidget> createState() => _PurchasingListWidgetState();
}

class _PurchasingListWidgetState extends State<PurchasingListWidget> {
  late Future<GetPurchasingByFarmerId> _future;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0);
  final _dateID = DateFormat('d MMM yyyy', 'id_ID');

  // offline indicators
  bool _isOfflineView = false;
  DateTime? _lastSync;
  StreamSubscription<dynamic>? _connSub;

  /// Queued-but-not-uploaded purchasing ops, refreshed together with [_load].
  PendingIndex _pending = PendingIndex.empty;

  /// Kenapa daftar ini berisi apa yang ditampilkan.
  RefreshOutcome _refreshOutcome = RefreshOutcome.fresh;

  final _api = PurchasingApi();

  @override
  void initState() {
    super.initState();
    _future = _load();
    _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
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
    if (!mounted) return;
    setState(() => _isOfflineView = !online);
    if (online) _refresh();
  }

  Future<GetPurchasingByFarmerId> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.farmerId ?? (prefs.getInt('id') ?? 0);
    if (id == 0) {
      throw Exception('Farmer ID tidak ditemukan. Silakan login ulang.');
    }

    // cek koneksi untuk banner
    final conn = await Connectivity().checkConnectivity();
    _isOfflineView = !_isOnlineFrom(conn);

    // cached-first agar tetap tampil saat offline
    final result = await _api.getPurchasingByFarmerIdCached(id);
    _refreshOutcome = result.outcome;
    final res = result.data;
    _lastSync = await _api.getPurchasingCacheTime(id);

    // Purchases with a queued change (e.g. a verification tapped offline) are
    // badged so the farmer can see they have not reached the server yet.
    _pending = await PurchasingApi.pendingIndex();

    return res;
  }

  void _refresh() {
    final next = _load(); // bangun future di luar setState
    setState(() {
      _future = next;
    });
  }

  String _fmtDate(DateTime? d) => d == null ? '-' : _dateID.format(d);

  String _fmtKg(String? qty) {
    if (qty == null || qty.trim().isEmpty) return '-';
    return qty.toLowerCase().contains('kg') ? qty : '$qty kg';
  }

  String _fmtMoney(num? v) => v == null ? '-' : _currency.format(v);

  String _fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    final isID = LanguageService.to.isId;
    final months = isID
        ? const ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']
        : const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return FutureBuilder<GetPurchasingByFarmerId>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              snap.error.toString(),
              style: ThemeTextStyle.textStyleForthBold.copyWith(color: Colors.red),
            ),
          );
        }

        final items = (snap.data?.data ?? <Datum>[]).toList()
          ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0))); // newest first

        // Header kecil: banner offline + info last sync
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isOfflineView)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5CC),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isID
                            ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                            : 'Offline mode: showing the last saved data.',
                        style: ThemeTextStyle.textStyleForthBold,
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: Text(isID ? 'Muat Ulang' : 'Reload'),
                    ),
                  ],
                ),
              ),
            if (!_isOfflineView)
              StaleDataBanner(
                outcome: _refreshOutcome,
                isID: isID,
                onRetry: _refresh,
              ),
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
          ],
        );

        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  isID ? 'Belum ada data setoran.' : 'No purchase data yet.',
                  style: ThemeTextStyle.textStyleThird,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            for (var i = 0; i < items.length; i++) ...[
              _buildPurchasingCard(items[i], isID),
              if (i != items.length - 1) const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
    });
  }

  Widget _buildPurchasingCard(Datum d, bool isID) {
    final pendingKind = _pending.kindFor(d.id);
    final warehouseName = d.warehouse?.warehouseName ?? '-';
    final date = _fmtDate(d.date);
    final commodity = d.commodity?.commoditiesName ?? '-';
    final grade = d.grade?.gradeName; // optional
    final qty = _fmtKg(d.quantity);
    final pricePerKg = d.pricePerKg; // int?
    final net = d.netPayment ?? d.valuePurchased; // prioritize net payment if available
    final pricePerKgStr = pricePerKg == null ? '-' : _fmtMoney(pricePerKg);
    final netStr = _fmtMoney(net);
    final hasDeduction = (d.deduction ?? 0) > 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pendingKind != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: PendingSyncBadge(kind: pendingKind, isID: isID),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoRow(
                  icon: Icons.warehouse_outlined,
                  label: isID ? 'Gudang' : 'Warehouse',
                  value: warehouseName),
              const SizedBox(height: 12),

              _buildInfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: isID ? 'Tanggal Beli' : 'Purchase Date',
                  value: date),
              const SizedBox(height: 12),

              _buildInfoRow(
                  icon: Icons.eco_outlined,
                  label: isID ? 'Komoditas' : 'Commodity',
                  value: commodity),
              if (grade != null && grade.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(icon: Icons.grade_outlined, label: 'Grade', value: grade),
              ],
              const SizedBox(height: 12),

              _buildInfoRow(
                  icon: Icons.scale_outlined,
                  label: isID ? 'Jumlah Pembelian' : 'Purchase Quantity',
                  value: qty),
              const SizedBox(height: 12),

              _buildInfoRow(
                  icon: Icons.attach_money,
                  label: isID ? 'Harga / kg' : 'Price / kg',
                  value: pricePerKgStr),
              const SizedBox(height: 12),

              _buildInfoRow(
                  icon: Icons.payments_outlined,
                  label: isID ? 'Total Bersih' : 'Net Total',
                  value: netStr),

              if (hasDeduction) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.remove_circle_outline,
                  label: isID ? 'Potongan' : 'Deduction',
                  value: _fmtMoney(d.deduction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: ThemeTextStyle.textStyleForthBold.copyWith(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
