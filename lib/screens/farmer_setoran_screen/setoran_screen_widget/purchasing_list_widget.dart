import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_farmer_id.dart';
import 'package:traceability_app/models/get_purchasing_by_id.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';
import 'package:traceability_app/utils/utils.dart';

import 'package:traceability_app/themes/app_tokens.dart';
// ─── Controller ──────────────────────────────────────────────────────────────

class PurchasingListController extends GetxController {
  final int? farmerId;
  PurchasingListController({this.farmerId});

  final _api = PurchasingApi();

  final language        = LanguageService.to.language;
  final isLoading       = false.obs;
  final error           = RxnString();
  final items           = <Datum>[].obs;
  final locallyVerified = <int>[].obs;

  /// Queued-but-not-uploaded purchasing ops — here that is mostly a verification
  /// tapped while offline, which stays in the status outbox until it syncs.
  final pending = PendingIndex.empty.obs;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp. ',
    decimalDigits: 0,
  );
  final _dateID = DateFormat('d MMM yyyy', 'id_ID');
  final _dateEN = DateFormat('d MMM yyyy', 'en_US');

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = farmerId ?? (prefs.getInt('id') ?? 0);
      if (id == 0) {
        throw Exception('Farmer ID tidak ditemukan. Silakan login ulang.');
      }
      // Status refresh-nya tidak disimpan di sini: layar Setoran yang memuat
      // widget ini sudah menampilkan StaleDataBanner dari controller-nya, jadi
      // dua peringatan untuk data yang sama hanya akan jadi kebisingan.
      final result = await _api.getPurchasingByFarmerIdCached(id);
      final loaded = (result.data.data ?? <Datum>[]).toList()
        ..sort((a, b) =>
            (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      items.value = loaded;

      // A verification tapped offline sits in the status outbox; badge its row
      // so the farmer can tell it has not reached the server yet. Queued
      // creates are not merged here — their body carries no farmer to scope on.
      pending.value = await PurchasingApi.pendingIndex();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<GetPurchasingById> fetchDetail(int id) =>
      _api.getPurchasingById(id);

  /// Pending state of a rendered row, or `null` when it is fully synced.
  PendingOpKind? pendingKindFor(int? rowId) => pending.value.kindFor(rowId);

  Future<String> verify(int purchasingId) async {
    final res = await _api.updatePurchasingStatusOfflineFirst(
      id: purchasingId,
      status: 'verified',
    );
    if (!locallyVerified.contains(purchasingId)) {
      locallyVerified.add(purchasingId);
    }
    await load();
    return res.message;
  }

  // ── Format helpers ──────────────────────────────────────────────────────

  String fmtDate(DateTime? d) {
    if (d == null) return '-';
    return language.value == 'id' ? _dateID.format(d) : _dateEN.format(d);
  }

  String fmtKg(String? qty) {
    if (qty == null || qty.trim().isEmpty) return '-';
    return qty.toLowerCase().contains('kg') ? qty : '$qty kg';
  }

  String fmtMoney(num? v) => v == null ? '-' : _currency.format(v);

  // ── Status helpers ──────────────────────────────────────────────────────

  String statusLabel(String s) {
    final isID = language.value == 'id';
    switch (s) {
      case 'verified':
        return isID ? 'Terverifikasi' : 'Verified';
      case 'failed':
        return isID ? 'Gagal' : 'Failed';
      case 'not_verified':
      default:
        return isID ? 'Belum Terverifikasi' : 'Not Verified';
    }
  }

  Color statusColor(String s) {
    switch (s) {
      case 'verified':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'not_verified':
      default:
        return Colors.orange;
    }
  }

  String extractStatus({required Datum fallback, required Object? detail}) {
    String s = (fallback.status ?? 'not_verified').toString();
    if (detail != null) {
      try {
        final dyn = detail as dynamic;
        final v   = dyn.status ?? dyn.statusPurchase ?? dyn.status_purchase;
        if (v != null) s = v.toString();
      } catch (_) {}
    }
    s = s.trim().toLowerCase();
    const allowed = {'verified', 'not_verified', 'failed'};
    if (!allowed.contains(s)) s = 'not_verified';
    return s;
  }

  // ── Image URL helpers ───────────────────────────────────────────────────

  // DB stores photo paths inconsistently: `/storage/foo.jpg`, `storage/foo.jpg`,
  // `/foo.jpg`, or `foo.jpg`. Normalise so the URL has a single `/storage/` segment.
  String resolveStorageUrl(String raw) {
    String t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    final api    = Uri.parse(AppConstants.baseUrl);
    final origin =
        '${api.scheme}://${api.host}${api.hasPort ? ':${api.port}' : ''}';
    t = t.replaceFirst(RegExp(r'^/+'), '');
    if (!t.startsWith('storage/')) {
      t = 'storage/app/public/$t';
    }
    return '$origin/$t';
  }
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class PurchasingListWidget extends StatelessWidget {
  final int? farmerId;
  const PurchasingListWidget({super.key, this.farmerId});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(
      () => PurchasingListController(farmerId: farmerId),
      tag: 'plist_${farmerId ?? 0}',
    );

    return Obx(() {
      final isLoading       = c.isLoading.value;
      final errorMsg        = c.error.value;
      final items           = c.items.toList();
      final locallyVerified = c.locallyVerified.toList();

      if (isLoading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (errorMsg != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            errorMsg,
            style: ThemeTextStyle
                .textStyleForthBold
                .copyWith(color: Colors.red),
          ),
        );
      }

      if (items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            c.language.value == 'id'
                ? 'Belum ada data pembelian.'
                : 'No purchase data yet.',
            style: ThemeTextStyle.textStyleThird,
          ),
        );
      }

      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildCard(context, c, items[i], locallyVerified),
            if (i != items.length - 1) const SizedBox(height: 6),
          ],
        ],
      );
    });
  }

  Widget _buildCard(
    BuildContext context,
    PurchasingListController c,
    Datum d,
    List<int> locallyVerified,
  ) {
    final id = d.id;
    var status = (d.status ?? 'not_verified').toString().toLowerCase();
    if (id != null && locallyVerified.contains(id)) status = 'verified';

    final isID          = c.language.value == 'id';
    final pendingKind   = c.pendingKindFor(id);
    final statusColor   = c.statusColor(status);
    final warehouseName = d.warehouse?.warehouseName ?? '-';
    final date          = c.fmtDate(d.date);
    final commodity     = d.commodity?.commoditiesName ?? '-';
    final grade         = d.grade?.gradeName;
    final qty           = c.fmtKg(d.quantity);
    final pricePerKg    = d.pricePerKg;
    final net           = d.netPayment ?? d.valuePurchased;
    final priceStr      = pricePerKg == null ? '-' : c.fmtMoney(pricePerKg);
    final netStr        = c.fmtMoney(net);
    final hasDeduction  = (d.deduction ?? 0) > 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2), width: 1),
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
              _infoRow(Icons.warehouse_outlined,
                  isID ? 'Gudang' : 'Warehouse', warehouseName),
              const SizedBox(height: 12),
              _infoRow(Icons.calendar_month_outlined,
                  isID ? 'Tanggal Beli' : 'Purchase Date', date),
              const SizedBox(height: 12),
              _infoRow(Icons.eco_outlined,
                  isID ? 'Komoditas' : 'Commodity', commodity),
              if (grade != null && grade.isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoRow(Icons.grade_outlined, 'Grade', grade),
              ],
              const SizedBox(height: 12),
              _infoRow(Icons.scale_outlined,
                  isID ? 'Jumlah Pembelian' : 'Purchase Quantity', qty),
              const SizedBox(height: 12),
              _infoRow(Icons.attach_money,
                  isID ? 'Harga / kg' : 'Price / kg', priceStr),
              const SizedBox(height: 12),
              _infoRow(Icons.payments_outlined,
                  isID ? 'Total Bersih' : 'Net Total', netStr),
              if (hasDeduction) ...[
                const SizedBox(height: 12),
                _infoRow(Icons.remove_circle_outline,
                    isID ? 'Potongan' : 'Deduction',
                    c.fmtMoney(d.deduction)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatusBtn(
                    label: isID ? 'Lihat Detail' : 'View Details',
                    color: Colors.blue,
                    onTap: id == null
                        ? null
                        : () => _showDetails(context, c, d),
                  ),
                  const Spacer(),
                  if (pendingKind != null) ...[
                    PendingSyncBadge(
                      kind: pendingKind,
                      isID: isID,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.xl),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      c.statusLabel(status),
                      style: ThemeTextStyle
                          .textStyleForthBold
                          .copyWith(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
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
            style: ThemeTextStyle
                .textStyleForthBold
                .copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── File-private helpers ─────────────────────────────────────────────────────

Future<void> _showDetails(
  BuildContext parentContext,
  PurchasingListController c,
  Datum d,
) async {
  if (d.id == null) return;

  await showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) {
          bool verifying = false;

          return StatefulBuilder(
            builder: (localCtx, setLocal) {
              return FutureBuilder<GetPurchasingById>(
                future: c.fetchDetail(d.id!),
                builder: (_, snap) {
                  Widget buildBody({
                    required String statusLocal,
                    String? warehouseName,
                    String? commodityName,
                    String? gradeName,
                    String? quantityStr,
                    num? pricePerKg,
                    num? valuePurchased,
                    num? deduction,
                    num? netPayment,
                    String? plotName,
                    DateTime? date,
                    String? proofValue,
                    String? proofDeduction,
                    String? proofPayment,
                    required bool showProofs,
                  }) {
                    final sc = c.statusColor(statusLocal);
                    final isID = LanguageService.to.isId;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(Icons.receipt_long),
                              const SizedBox(width: 8),
                              Text(
                                isID ? 'Detail Pembelian' : 'Purchase Details',
                                style: ThemeTextStyle.textStyleSecond,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sc.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(Radii.xl),
                                  border: Border.all(
                                      color: sc.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  c.statusLabel(statusLocal),
                                  style: ThemeTextStyle
                                      .textStyleForthBold
                                      .copyWith(color: sc, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Body
                          Expanded(
                            child: ListView(
                              controller: scrollCtrl,
                              children: [
                                _detailRow(
                                    isID ? 'Tanggal' : 'Date',
                                    c.fmtDate(date)),
                                _detailRow(
                                    isID ? 'Gudang' : 'Warehouse',
                                    _orDash(warehouseName)),
                                _detailRow(
                                    isID ? 'Komoditas' : 'Commodity',
                                    _orDash(commodityName)),
                                if ((gradeName ?? '').trim().isNotEmpty)
                                  _detailRow('Grade', gradeName!),
                                _detailRow(
                                    isID ? 'Jumlah' : 'Quantity',
                                    c.fmtKg(quantityStr)),
                                _detailRow(
                                    isID ? 'Harga/kg' : 'Price/kg',
                                    c.fmtMoney(pricePerKg)),
                                _detailRow(
                                    isID ? 'Nilai Pembelian' : 'Purchase Value',
                                    c.fmtMoney(valuePurchased)),
                                _detailRow(
                                    isID ? 'Potongan' : 'Deduction',
                                    c.fmtMoney(deduction)),
                                _detailRow(
                                    isID ? 'Pembayaran Bersih' : 'Net Payment',
                                    c.fmtMoney(netPayment)),
                                _detailRow('Plot', _orDash(plotName)),
                                const SizedBox(height: 12),
                                if (showProofs) ...[
                                  _proofTile(
                                    parentContext: parentContext,
                                    c: c,
                                    label: isID
                                        ? 'Bukti Nilai'
                                        : 'Value Proof',
                                    path: proofValue,
                                  ),
                                  _proofTile(
                                    parentContext: parentContext,
                                    c: c,
                                    label: isID
                                        ? 'Bukti Potongan'
                                        : 'Deduction Proof',
                                    path: proofDeduction,
                                  ),
                                  _proofTile(
                                    parentContext: parentContext,
                                    c: c,
                                    label: isID
                                        ? 'Bukti Pembayaran'
                                        : 'Payment Proof',
                                    path: proofPayment,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Footer: verify button
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                      Icons.verified_outlined),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        statusLocal == 'verified'
                                            ? Colors.green
                                                .withValues(alpha: 0.4)
                                            : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  onPressed:
                                      (statusLocal == 'verified' ||
                                              verifying)
                                          ? null
                                          : () async {
                                              setLocal(
                                                  () => verifying = true);
                                              try {
                                                final msg =
                                                    await c.verify(d.id!);
                                                if (ctx.mounted &&
                                                    Navigator.of(ctx)
                                                        .canPop()) {
                                                  Navigator.of(ctx).pop();
                                                }
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback(
                                                        (_) {
                                                  if (parentContext
                                                      .mounted) {
                                                    ScaffoldMessenger
                                                            .maybeOf(
                                                                parentContext)
                                                        ?.showSnackBar(
                                                            SnackBar(
                                                                content:
                                                                    Text(msg)));
                                                  }
                                                });
                                              } catch (e) {
                                                if (parentContext.mounted) {
                                                  ScaffoldMessenger.maybeOf(
                                                          parentContext)
                                                      ?.showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Gagal verifikasi: $e')));
                                                }
                                              } finally {
                                                setLocal(() =>
                                                    verifying = false);
                                              }
                                            },
                                  label: Text(
                                    statusLocal == 'verified'
                                        ? 'Sudah Terverifikasi'
                                        : 'Verifikasi',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snap.hasData && snap.data?.data != null) {
                    final data = snap.data!.data!;
                    return buildBody(
                      statusLocal: c.extractStatus(
                          fallback: d, detail: data),
                      warehouseName: data.warehouse?.warehouseName,
                      commodityName: data.commodity?.commoditiesName,
                      gradeName: data.grade?.gradeName,
                      quantityStr: data.quantity?.toString(),
                      pricePerKg: data.pricePerKg,
                      valuePurchased: data.valuePurchased,
                      deduction: data.deduction,
                      netPayment: data.netPayment,
                      plotName: data.plot?.plotName,
                      date: data.date,
                      proofValue: data.uploadProofValue,
                      proofDeduction: data.uploadProofDeduction,
                      proofPayment: data.uploadProofPayment,
                      showProofs: true,
                    );
                  }

                  return buildBody(
                    statusLocal:
                        c.extractStatus(fallback: d, detail: null),
                    warehouseName: d.warehouse?.warehouseName,
                    commodityName: d.commodity?.commoditiesName,
                    gradeName: d.grade?.gradeName,
                    quantityStr: d.quantity,
                    pricePerKg: d.pricePerKg,
                    valuePurchased: d.valuePurchased,
                    deduction: d.deduction,
                    netPayment: d.netPayment ?? d.valuePurchased,
                    plotName: d.plot?.plotName,
                    date: d.date,
                    showProofs: false,
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

void _showImage(
    BuildContext context, PurchasingListController c, String raw) {
  final url = c.resolveStorageUrl(raw);
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(Insets.md),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, evt) => evt == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white70, size: 64),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Tutup',
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _proofTile({
  required BuildContext parentContext,
  required PurchasingListController c,
  required String label,
  String? path,
}) {
  final has     = path != null && path.trim().isNotEmpty && path != '-';
  final display = has ? path : '-';
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.image_outlined),
    title: Text(label, style: ThemeTextStyle.textStyleForthBold),
    subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: has
        ? TextButton.icon(
            onPressed: () => _showImage(parentContext, c, display),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Lihat'),
          )
        : null,
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: ThemeTextStyle.textStyleForthBold.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              Text(value, style: ThemeTextStyle.textStyleForthBold),
        ),
      ],
    ),
  );
}

String _orDash(String? v) {
  if (v == null) return '-';
  final s = v.trim();
  return s.isEmpty ? '-' : s;
}

// ─── _StatusBtn ───────────────────────────────────────────────────────────────

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _StatusBtn({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color : color.withValues(alpha: 0.3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
