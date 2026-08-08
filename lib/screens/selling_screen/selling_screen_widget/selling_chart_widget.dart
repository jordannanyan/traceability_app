import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:traceability_app/models/get_selling_by_kth_id.dart' as model;
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class MonthlyPoint {
  final DateTime month;
  final double value;
  MonthlyPoint({required this.month, required this.value});
}

class SellingMonthlyChart extends StatelessWidget {
  final List<model.Datum> items;
  final String language;
  final int monthsBack;
  final double height;

  const SellingMonthlyChart({
    super.key,
    required this.items,
    required this.language,
    this.monthsBack = 6,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final series = _monthlyNetSales(items, monthsBack: monthsBack);
    final rawMax = series.fold<double>(0, (m, e) => math.max(m, e.value));
    final maxY = (rawMax * 1.2).clamp(1, double.infinity).toDouble();
    final interval = (maxY / 4).clamp(1, double.infinity).toDouble();

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = series[group.x.toInt()];
                return BarTooltipItem(
                  '${_monthLabel(p.month, language)}\n${_fmtMoneyFull(p.value)}',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  const eps = 1e-6;
                  final m = (value / meta.appliedInterval);
                  final isMultiple = (m - m.round()).abs() < eps;
                  if (!isMultiple || value < 0 || value > maxY + eps) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _fmtMoneyShort(value),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
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
                  if (i < 0 || i >= series.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _monthLabel(series[i].month, language),
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].value,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
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

  static List<MonthlyPoint> _monthlyNetSales(
    List<model.Datum> items, {
    required int monthsBack,
  }) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = monthsBack - 1; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i));
    }
    final map = {for (final m in months) _monthKey(m): 0.0};

    for (final d in items) {
      final dt = d.date;
      if (dt == null) continue;
      final key = _monthKey(DateTime(dt.year, dt.month));
      if (!map.containsKey(key)) continue;
      final v = _parseNum(d.totalNetSales) ?? _parseNum(d.totalPrice) ?? 0;
      map[key] = (map[key] ?? 0) + v.toDouble();
    }

    return months
        .map((m) => MonthlyPoint(month: m, value: map[_monthKey(m)] ?? 0))
        .toList();
  }

  static num? _parseNum(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final cleaned =
        s.replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime month, String lang) {
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final arr = lang == 'id' ? id : en;
    return '${arr[month.month - 1]} ${month.year % 100}';
  }

  static String _fmtMoneyShort(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}M';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}jt';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  static String _fmtMoneyFull(double v) {
    final f = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return f.format(v);
  }
}
