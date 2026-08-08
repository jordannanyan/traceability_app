import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:traceability_app/models/get_selling_by_kth_id.dart' as model;
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SellingList extends StatelessWidget {
  final List<model.Datum> items;
  final String language;

  const SellingList({
    super.key,
    required this.items,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            language == 'id'
                ? 'Belum ada penjualan.'
                : 'No selling data yet.',
            style: ThemeTextStyle
                .textStyleForthBold
                .copyWith(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sorted = [...items]
      ..sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          SellingCard(item: sorted[i], language: language),
    );
  }
}

class SellingCard extends StatelessWidget {
  final model.Datum item;
  final String language;

  const SellingCard({
    super.key,
    required this.item,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final isID = language == 'id';

    String money(dynamic s) {
      final n = _parseNum(s?.toString());
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp',
        decimalDigits: 0,
      ).format(n ?? 0);
    }

    String fmtDate(DateTime? d) {
      if (d == null) return '-';
      const idMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      const enMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final arr = isID ? idMonths : enMonths;
      return '${d.day.toString().padLeft(2, '0')} ${arr[d.month - 1]} ${d.year}';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: const Icon(
                    Icons.handshake_outlined,
                    color: Colors.green,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offtaker: ${item.offTaker?.offtakerName ?? '-'}',
                    style: ThemeTextStyle.textStyleForthBold.copyWith(
                          color: ThemeColor.darkestGreen,
                          fontSize: 14,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fmtDate(item.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(
              Icons.warehouse_outlined,
              isID ? 'Gudang' : 'Warehouse',
              item.warehouse?.warehouseName ?? '-',
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.category_outlined,
              isID ? 'Komoditas' : 'Commodity',
              item.commodity?.commoditiesName ?? '-',
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.workspace_premium_outlined,
              'Grade',
              item.grade?.gradeName ?? '-',
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.scale_outlined,
              isID ? 'Jumlah' : 'Quantity',
              '${item.quantity ?? 0} kg',
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.sell_outlined,
              isID ? 'Harga/Kg' : 'Price/Kg',
              money(item.pricePerKg),
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.summarize_outlined,
              isID ? 'Total Harga' : 'Total Price',
              money(item.totalPrice),
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.receipt_long_outlined,
              isID ? 'Pajak/Potongan' : 'Taxes/Deductions',
              money(item.taxesOrDeductions),
            ),
            const SizedBox(height: 6),
            _infoRow(
              Icons.payments_outlined,
              isID ? 'Penjualan Bersih' : 'Net Sales',
              money(item.totalNetSales),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.grey.shade700),
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
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static num? _parseNum(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final cleaned =
        s.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }
}
