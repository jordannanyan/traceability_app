// lib/screens/purchasing_screen/purchasing_screen_widget/purchasing_card_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PurchasingCardWidget extends StatelessWidget {
  final GetPurchasingByKthId purchasingData;
  final String language;
  final bool isOffline;
  final Future<void> Function()? onEdited;

  /// Pending (outbox) state per row id — rows not in it are fully synced.
  final PendingOpKind? Function(int? id)? pendingKindFor;

  const PurchasingCardWidget({
    super.key,
    required this.purchasingData,
    required this.language,
    this.onEdited,
    this.isOffline = false,
    this.pendingKindFor,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...purchasingData.data]
      ..sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    if (sorted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            language == 'id'
                ? 'Belum ada riwayat Pembelian.'
                : 'No purchasing history.',
            style: ThemeTextStyle
                .textStyleForthBold
                .copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PurchasingCard(
        item: sorted[i],
        language: language,
        isOffline: isOffline,
        onEdited: onEdited,
        pendingKind: pendingKindFor?.call(sorted[i].id),
      ),
    );
  }
}

class _PurchasingCard extends StatelessWidget {
  final Datum item;
  final String language;
  final bool isOffline;
  final Future<void> Function()? onEdited;

  /// Non-null when this row is still queued in the outbox.
  final PendingOpKind? pendingKind;

  const _PurchasingCard({
    required this.item,
    required this.language,
    this.onEdited,
    this.isOffline = false,
    this.pendingKind,
  });

  bool get isID => language == 'id';

  /// A queued create has no server record, and a queued delete is on its way
  /// out — neither can be opened in the edit screen.
  bool get _isLocked =>
      pendingKind == PendingOpKind.create ||
      pendingKind == PendingOpKind.delete;

  @override
  Widget build(BuildContext context) {

    final qty = (item.quantity ?? '0').toString();
    final ppk = _toNum(item.pricePerKg);
    final gross = _toNum(item.valuePurchased);
    final ded = _toNum(item.deduction);
    final net = _toNum(item.netPayment);

    final hasSignature = _has(item.signatureImage);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const _IconBadge(icon: Icons.shopping_bag_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${isID ? 'Pembelian' : 'Purchasing'} • ${_fmtDate(item.date)}',
                    style: ThemeTextStyle.textStyleForthBold.copyWith(
                          color: ThemeColor.darkestGreen,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pendingKind != null) ...[
                  const SizedBox(width: 8),
                  PendingSyncBadge(
                    kind: pendingKind!,
                    isID: isID,
                    compact: true,
                  ),
                ],
                const SizedBox(width: 8),
                _QtyPill(qty: qty, language: language),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  tooltip: _isLocked
                      ? (isID
                          ? 'Menunggu sinkron'
                          : 'Waiting to sync')
                      : isOffline
                      ? (isID
                          ? 'Tidak tersedia saat offline'
                          : 'Unavailable offline')
                      : 'Edit',
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: (isOffline || _isLocked) ? Colors.grey : Colors.blue,
                  ),
                  onPressed: (isOffline || _isLocked)
                      ? null
                      : () async {
                          final changed = await Navigator.pushNamed(
                            context,
                            '/edit-purchasing',
                            arguments: item,
                          );
                          if (changed == true) {
                            await onEdited?.call();
                          }
                        },
                ),
              ],
            ),

            const SizedBox(height: 12),
            _divider(),

            const SizedBox(height: 12),
            _infoRow(Icons.warehouse_outlined, isID ? 'Gudang' : 'Warehouse',
                item.warehouse?.warehouseName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(
              Icons.location_on_outlined,
              isID ? 'Alamat Gudang' : 'Warehouse Address',
              item.warehouse?.address ?? '-',
              multiline: true,
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.park_outlined, isID ? 'Lahan' : 'Plot',
                item.plot?.plotName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.category_outlined,
                isID ? 'Komoditas' : 'Commodity',
                item.commodity?.commoditiesName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.workspace_premium_outlined, 'Grade',
                item.grade?.gradeName ?? '-'),

            const SizedBox(height: 12),
            _divider(),

            const SizedBox(height: 12),
            _infoRow(Icons.scale_outlined, isID ? 'Jumlah' : 'Quantity',
                '$qty kg'),
            const SizedBox(height: 8),
            _infoRow(Icons.sell_outlined, isID ? 'Harga/Kg' : 'Price/Kg',
                _fmtMoney(ppk)),
            const SizedBox(height: 8),
            _infoRow(
              Icons.receipt_long_outlined,
              isID ? 'Nilai Pembelian (Bruto)' : 'Value Purchased (Gross)',
              _fmtMoney(gross),
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.indeterminate_check_box_outlined,
              isID ? 'Potongan' : 'Deduction',
              _fmtMoney(ded),
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.payments_outlined,
              isID ? 'Pembayaran Bersih' : 'Net Payment',
              _fmtMoney(net),
              emphasize: true,
            ),

            const SizedBox(height: 12),
            _divider(),

            const SizedBox(height: 12),
            _proofButtons(context),
            const SizedBox(height: 8),

            Row(
              children: [
                if (hasSignature)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      isID ? 'Tanda Tangan' : 'Signature',
                      style: const TextStyle(fontSize: 10),
                    ),
                    onPressed: () =>
                        _showImage(context, item.signatureImage.toString()),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      isOffline ? null : () => _openSignaturePad(context),
                  icon: const Icon(Icons.draw),
                  label: Text(
                    isID
                        ? (hasSignature
                            ? 'Tanda tangani ulang'
                            : 'Tanda tangani')
                        : (hasSignature ? 'Re-sign' : 'Sign'),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _divider(),

            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${isID ? "Dibuat" : "Created"}: ${_fmtDateTime(item.createdAt)} • '
                    '${isID ? "Update" : "Updated"}: ${_fmtDateTime(item.updatedAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Signature pad ─────────────────────────────────────────────────────────

  Future<void> _openSignaturePad(BuildContext context) async {
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isID
              ? 'Tidak tersedia saat offline'
              : 'Unavailable offline'),
        ),
      );
      return;
    }
    if (item.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isID
              ? 'ID pembelian tidak ditemukan'
              : 'Purchasing ID not found'),
        ),
      );
      return;
    }

    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    bool saving = false;

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isID ? 'Tanda Tangan' : 'Signature'),
          content: SizedBox(
            width: double.maxFinite,
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Container(
                color: Colors.grey.shade200,
                child: Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => controller.clear(),
              child: Text(isID ? 'Bersihkan' : 'Clear'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: Text(isID ? 'Batal' : 'Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (controller.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(isID
                                ? 'Silakan gambar tanda tangan dulu.'
                                : 'Please draw the signature first.'),
                          ),
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final bytes = await controller.toPngBytes();
                        if (bytes == null || bytes.isEmpty) {
                          throw Exception('Gagal mengekspor tanda tangan');
                        }

                        final dir = await getTemporaryDirectory();
                        final file = File(
                          '${dir.path}/signature_${item.id}_${DateTime.now().millisecondsSinceEpoch}.png',
                        );
                        await file.writeAsBytes(bytes);

                        final api = PurchasingApi();
                        await api.editPurchasing(
                          id: item.id!,
                          requestData: {'signature_image': file},
                        );

                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                saving
                    ? (isID ? 'Menyimpan...' : 'Saving...')
                    : (isID ? 'Simpan' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await onEdited?.call();
    }
  }

  // ── UI atoms ──────────────────────────────────────────────────────────────

  Widget _divider() => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.grey.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
      );

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool multiline = false,
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 13,
                    color: emphasize ? Colors.black : Colors.grey.shade800,
                    fontWeight:
                        emphasize ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _proofButtons(BuildContext context) {
    final hasV = _has(item.uploadProofValue);
    final hasD = _has(item.uploadProofDeduction);
    final hasP = _has(item.uploadProofPayment);

    if (!hasV && !hasD && !hasP) {
      return Row(
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            isID ? 'Tidak ada bukti terlampir' : 'No proofs attached',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasV)
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(
              isID ? 'Bukti Nilai' : 'Value Proof',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () =>
                _showImage(context, item.uploadProofValue!.toString()),
          ),
        if (hasD)
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(
              isID ? 'Bukti Potongan' : 'Deduction Proof',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () =>
                _showImage(context, item.uploadProofDeduction!.toString()),
          ),
        if (hasP)
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(
              isID ? 'Bukti Pembayaran' : 'Payment Proof',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () =>
                _showImage(context, item.uploadProofPayment!.toString()),
          ),
      ],
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final cleaned =
        s.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final d = double.tryParse(cleaned);
    return (d == null || d.isNaN || d.isInfinite) ? 0 : d;
  }

  static String _fmtMoney(num v) => NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp',
        decimalDigits: 0,
      ).format(v);

  static String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${id[d.month - 1]} ${d.year}';
  }

  static String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd MMM yyyy HH:mm').format(d);
  }

  bool _has(dynamic s) => s != null && s.toString().trim().isNotEmpty;

  void _showImage(BuildContext context, String raw) {
    final url = _resolveStorageUrl(raw);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(Insets.lg),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (c, child, evt) =>
                  evt == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (c2, e2, st2) =>
                  const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          ),
        ),
      ),
    );
  }

  // DB stores photo paths inconsistently: `/storage/foo.jpg`, `storage/foo.jpg`,
  // `/foo.jpg`, or `foo.jpg`. Normalise to a single `storage/` prefix.
  String _resolveStorageUrl(String s) {
    String t = s.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    t = t.replaceFirst(RegExp(r'^/+'), '');
    if (!t.startsWith('storage/')) {
      t = 'storage/$t';
    }
    return 'https://app.nbsvworldwide.com/$t';
  }
}

// ── small UI atoms ────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade900.withValues(alpha: 0.10),
            Colors.green.shade900.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
            color: Colors.green.shade900.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, size: 16, color: Colors.green.shade900),
    );
  }
}

class _QtyPill extends StatelessWidget {
  final String qty;
  final String language;
  const _QtyPill({required this.qty, required this.language});

  @override
  Widget build(BuildContext context) {
    const c = Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.scale_outlined, size: 14),
          const SizedBox(width: 4),
          Text(
            '$qty kg',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
