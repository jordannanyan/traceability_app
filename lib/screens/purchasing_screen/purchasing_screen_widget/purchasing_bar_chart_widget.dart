import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PurchasingBarChart extends StatelessWidget {
  final GetPurchasingByKthId data;
  final int monthsBack;      // match the other bar (default 6)
  final double height;       // container height inside the card
  final String language;     // 'id' or 'en' (default 'id')

  const PurchasingBarChart(
    this.data, {
    super.key,
    this.monthsBack = 6,
    this.height = 240,
    this.language = 'id',
  });

  @override
  Widget build(BuildContext context) {
    final series = _monthlyNetPayment(data.data, monthsBack: monthsBack);

    // Max + padding like the Selling chart
    final rawMax = series.fold<double>(0, (m, p) => math.max(m, p.value));
    final maxY = (rawMax * 1.2).clamp(1, double.infinity).toDouble();
    final interval = (maxY / 4).clamp(1, double.infinity).toDouble();

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = series[group.x.toInt()];
                return BarTooltipItem(
                  '${_monthLabel(p.month, language)}\n${_fmtMoneyFull(p.value)}',
                  ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  const eps = 1e-6;
                  final m = (value / meta.appliedInterval);
                  final isMultiple = (m - m.round()).abs() < eps;
                  if (!isMultiple || value < 0 || value > maxY + eps) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _fmtMoneyShort(value),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthLabel(series[i].month, language),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].value,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ThemeColor.darkestGreen.withValues(alpha: 0.9),
                        ThemeColor.darkestGreen.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Aggregate last [monthsBack] months of net payment.
  static List<_MonthlyPoint> _monthlyNetPayment(
    List<Datum> items, {
    required int monthsBack,
  }) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = monthsBack - 1; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i));
    }
    final buckets = {for (final m in months) _monthKey(m): 0.0};

    for (final d in items) {
      final dt = d.date;
      if (dt == null) continue;
      final key = _monthKey(DateTime(dt.year, dt.month));
      if (!buckets.containsKey(key)) continue;

      // netPayment can be num or String — parse robustly
      final v = _parseNum(d.netPayment) ?? 0;
      buckets[key] = (buckets[key] ?? 0) + v.toDouble();
    }

    return months
        .map((m) => _MonthlyPoint(month: m, value: buckets[_monthKey(m)] ?? 0))
        .toList();
  }

  static num? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final d = double.tryParse(cleaned);
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  static String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime month, String lang) {
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const id = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final arr = lang == 'en' ? en : id;
    return '${arr[month.month - 1]} ${month.year % 100}';
  }

  static String _fmtMoneyShort(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}M';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}jt';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  static String _fmtMoneyFull(double v) {
    final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    return f.format(v);
  }
}

class _MonthlyPoint {
  final DateTime month;
  final double value;
  _MonthlyPoint({required this.month, required this.value});
}
