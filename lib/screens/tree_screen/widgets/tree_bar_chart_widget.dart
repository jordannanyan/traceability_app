// lib/screens/tree_screen/widgets/tree_bar_chart_widget.dart
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_trees.dart' as tm; // ← pakai model API
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeBarChart extends StatelessWidget {
  /// Sumber data: daftar Tree dari API
  final List<tm.Datum> trees;
  /// Berapa bulan ke belakang yang ditampilkan
  final int monthsBack;
  /// Tinggi container di dalam card
  final double height;
  /// 'id' atau 'en' untuk label bulan
  final String language;

  const TreeBarChart(
    this.trees, {
    super.key,
    this.monthsBack = 6,
    this.height = 240,
    this.language = 'id',
  });

  @override
  Widget build(BuildContext context) {
    final series = _monthlyPlantCounts(trees, monthsBack: monthsBack);

    // kalau kosong, tetap render sumbu dengan 0
    final rawMax = series.isEmpty ? 0.0 : series.fold<double>(0, (m, p) => math.max(m, p.value));
    final maxY = math.max(1.0, rawMax * 1.2);
    final interval = math.max(1.0, maxY / 4);

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
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final idx = group.x.toInt();
                if (idx < 0 || idx >= series.length) return null;
                final p = series[idx];
                final unit = language == 'en' ? 'trees' : 'pohon';
                return BarTooltipItem(
                  '${_monthLabel(p.month, language)}\n${_fmtCount(p.value)} $unit',
                  ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
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
                      _fmtLeftAxis(value),
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

  /// Agregasi jumlah pohon yang ditanam per bulan untuk [monthsBack] terakhir
  static List<_MonthlyPoint> _monthlyPlantCounts(
    List<tm.Datum> trees, {
    required int monthsBack,
  }) {
    final now = DateTime.now();
    // buat deretan bulan (awal tiap bulan) mundur ke belakang
    final months = <DateTime>[];
    for (int i = monthsBack - 1; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    final buckets = {for (final m in months) _monthKey(m): 0.0};

    for (final t in trees) {
      // plantingDate di model API bisa null; handle aman
      final dt = _ensureDate(t.plantingDate);
      if (dt == null) continue;
      final key = _monthKey(DateTime(dt.year, dt.month, 1));
      if (buckets.containsKey(key)) {
        buckets[key] = (buckets[key] ?? 0) + 1.0; // hitung JUMLAH pohon
      }
    }

    return months
        .map((m) => _MonthlyPoint(month: m, value: buckets[_monthKey(m)] ?? 0))
        .toList();
  }

  /// Parsing aman: DateTime? | String? → DateTime?
  static DateTime? _ensureDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.tryParse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime month, String lang) {
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const id = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final arr = lang == 'en' ? en : id;
    return '${arr[month.month - 1]} ${month.year % 100}';
  }

  static String _fmtLeftAxis(double v) {
    if (v >= 1000) return NumberFormat.compact(locale: 'id_ID').format(v);
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  static String _fmtCount(double v) => v.toStringAsFixed(0);
}

class _MonthlyPoint {
  final DateTime month;
  final double value;
  _MonthlyPoint({required this.month, required this.value});
}
