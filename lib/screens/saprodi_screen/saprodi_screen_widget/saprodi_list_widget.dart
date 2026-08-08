import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_distributed_saprodi_by_plot_id.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SaprodiListWidget extends StatelessWidget {
  final List<Datum> items;
  final String language;

  const SaprodiListWidget({
    super.key,
    required this.items,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final d in items) ...[
          _SaprodiCard(d: d, language: language),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SaprodiCard extends StatelessWidget {
  final Datum d;
  final String language;

  const _SaprodiCard({required this.d, required this.language});

  @override
  Widget build(BuildContext context) {
    final dateStr = d.date != null ? _fmtDate(d.date!, language) : '-';
    final name = d.sapropdi?.sapropdiName ?? '-';
    final unit = d.sapropdi?.unit ?? '';
    final commodity = d.commodities?.commoditiesName ?? '-';
    final plot = d.plot?.plotName ?? '-';
    final qty = (d.quantity ?? 0);
    final priceUnitStr = _fmtMoney(_parseNum(d.pricePerUnit) ?? 0);
    final totalStr = _fmtMoney(_parseNum(d.totalPrice) ?? (_parseNum(d.pricePerUnit) ?? 0) * qty);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
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
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: saprodi name + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: ThemeColor.darkestGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _info(
              icon: Icons.eco_outlined,
              label: language == 'id' ? 'Komoditas' : 'Commodity',
              value: commodity,
            ),
            const SizedBox(height: 10),
            _info(
              icon: Icons.terrain_outlined,
              label: language == 'id' ? 'Plot' : 'Plot',
              value: plot,
            ),

            const Divider(height: 24),

            // Quantity and prices
            Row(
              children: [
                Expanded(
                  child: _pill(
                    label: language == 'id' ? 'Jumlah' : 'Quantity',
                    value: '$qty ${unit.isNotEmpty ? unit : ''}'.trim(),
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pill(
                    label: language == 'id' ? 'Harga/Unit' : 'Price/Unit',
                    value: priceUnitStr,
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pill(
                    label: 'Total',
                    value: totalStr,
                    icon: Icons.monetization_on,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: ThemeTextStyle.textStyleForthBold.copyWith(color: Colors.grey.shade600, fontSize: 14),
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

  Widget _pill({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d, String lang) {
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const id = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final arr = lang == 'id' ? id : en;
    return '${d.day.toString().padLeft(2, '0')} ${arr[d.month - 1]} ${d.year}';
  }

  static num? _parseNum(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  static String _fmtMoney(num v) {
    final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return f.format(v);
  }
}
