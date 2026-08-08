import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_distributed_saprodi_by_plot_id.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class _YAxisScale {
  final double max;
  final double interval;
  const _YAxisScale(this.max, this.interval);
}

_YAxisScale _niceYAxis(double rawMax, {int ticks = 5}) {
  if (rawMax <= 0) return const _YAxisScale(1, 1);

  double niceNum(double x, {required bool round}) {
    final expv = (math.log(x) / math.ln10).floor();
    final f = x / math.pow(10.0, expv);
    double nf;
    if (round) {
      if (f < 1.5) {
        nf = 1;
      } else if (f < 3) {
        nf = 2;
      } else if (f < 7) {
        nf = 5;
      } else {
        nf = 10;
      }
    } else {
      if (f <= 1) {
        nf = 1;
      } else if (f <= 2) {
        nf = 2;
      } else if (f <= 5) {
        nf = 5;
      } else {
        nf = 10;
      }
    }
    return nf * math.pow(10.0, expv);
  }

  final nTicks = ticks.clamp(2, 10);
  final tick = niceNum(rawMax / (nTicks - 1), round: true);
  final max = ((rawMax / tick).ceil() * tick).toDouble();
  return _YAxisScale(max, tick);
}

/// Kg vs Rupiah analog for saprodi:
/// qty  -> sum of `quantity` (unit-less aggregate)
/// net  -> sum of totalPrice (parsed) or pricePerUnit * quantity
enum SaprodiMetric { qty, net }

class SaprodiMonthlyChart extends StatelessWidget {
  final List<Datum> items;
  final SaprodiMetric metric;
  final String language; // 'id' | 'en'
  final int monthsBack;
  final double height;

  const SaprodiMonthlyChart({
    super.key,
    required this.items,
    required this.metric,
    required this.language,
    this.monthsBack = 6,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final series = _buildMonthlyBuckets(items, monthsBack: monthsBack, metric: metric);

    // --- FIX: nice, aligned axis so the top tick equals maxY ---
    final rawMax = series.fold<double>(0, (m, e) => math.max(m, e.value));
    final scale = _niceYAxis(rawMax, ticks: 5);
    final maxY = scale.max;
    final intervalY = scale.interval;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,                 // <-- explicit
          maxY: maxY,              // <-- nice top
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = series[group.x.toInt()];
                final label = metric == SaprodiMetric.qty ? _fmtQtyFull(p.value) : _fmtMoneyFull(p.value);
                return BarTooltipItem(
                  '${_monthLabel(p.month, language)}\n$label',
                  ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 12),
                );
              },
            ),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: intervalY, // <-- use exact interval
                getTitlesWidget: (value, meta) {
                  const eps = 1e-6;
                  final ratio = value / intervalY;
                  final isMultiple = (ratio - ratio.round()).abs() < eps;
                  if (!isMultiple || value < 0 || value > maxY + eps) {
                    return const SizedBox.shrink();
                  }
                  final label = metric == SaprodiMetric.qty ? _fmtQtyShort(value) : _fmtMoneyShort(value);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                    child: Text(_monthLabel(series[i].month, language), style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

  // ── buckets ──────────────────────────────────────────────────────────────
  static List<_MonthlyPoint> _buildMonthlyBuckets(
    List<Datum> items, {
    required int monthsBack,
    required SaprodiMetric metric,
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

      final add = (metric == SaprodiMetric.qty)
          ? _asDouble(d.quantity) // ✅ aman walau String/num/null
          : _moneyValue(d);

      map[key] = (map[key] ?? 0) + add;
    }

    return months.map((m) => _MonthlyPoint(month: m, value: map[_monthKey(m)] ?? 0)).toList();
  }

  static double _moneyValue(Datum d) {
    // prefer totalPrice if present, else pricePerUnit * quantity
    final total = _parseNum(d.totalPrice);
    if (total != null) return total.toDouble();

    final unit = _parseNum(d.pricePerUnit) ?? 0;
    final qty = _asDouble(d.quantity);
    return unit.toDouble() * qty;
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final cleaned = s.replaceAll(RegExp(r'[^0-9,\.\-]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  static num? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    final cleaned = s.replaceAll(RegExp(r'[^0-9,\.\-]'), '').replaceAll(',', '.');
    final x = double.tryParse(cleaned);
    if (x == null || x.isNaN || x.isInfinite) return null;
    return x;
  }


  static String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _monthLabel(DateTime month, String lang) {
    const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const id = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final arr = lang == 'id' ? id : en;
    return '${arr[month.month - 1]} ${month.year % 100}';
  }

  static String _fmtQtyShort(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
  }

  static String _fmtQtyFull(double v) {
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
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
