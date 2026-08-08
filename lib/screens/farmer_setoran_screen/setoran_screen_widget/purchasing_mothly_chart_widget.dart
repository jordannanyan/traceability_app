import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_purchasing_by_farmer_id.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
enum PurchasingMetric { kg, net }

class PurchasingMonthlyChart extends StatelessWidget {
  final List<Datum> items;
  final PurchasingMetric metric;
  final String language; // 'id' or 'en'
  final int monthsBack;
  final double height;

  const PurchasingMonthlyChart({
    super.key,
    required this.items,
    required this.metric,
    required this.language,
    this.monthsBack = 6,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final series = _buildMonthlyBuckets(
      items,
      monthsBack: monthsBack,
      metric: metric,
    );

    // Raw max (ensure > 0 to avoid divide-by-zero)
    final rawMax = series.fold<double>(0, (m, e) => math.max(m, e.value));
    final _Scale scale = (metric == PurchasingMetric.kg)
        ? _niceScale(rawMax, 5, base: 10) // e.g., 0, 25, 50, 75, 100 kg
        : _niceScale(rawMax, 5, base: 10); // e.g., 0, 250rb, 500rb, 750rb, 1jt

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
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
          minY: 0, // <- baseline at 0
          maxY: scale.max, // <- nice rounded max (no 20% headroom)
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = series[group.x.toInt()];
                final label = metric == PurchasingMetric.kg
                    ? _fmtKgFull(p.value)
                    : _fmtMoneyFull(p.value);
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
                interval: scale.step, // <- fixed interval; no rounding
                getTitlesWidget: (value, meta) {
                  // Only multiples of the applied interval in [0, max]
                  const eps = 1e-6;
                  final m = (value / meta.appliedInterval);
                  final isMultiple = (m - m.round()).abs() < eps;
                  if (!isMultiple || value < -eps || value > scale.max + eps)
                  {
                    return const SizedBox.shrink();
                  }
                  final label = metric == PurchasingMetric.kg
                      ? _fmtKgShort(value)
                      : _fmtMoneyShort(value);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1, // one label per month index
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= series.length)
                  {
                    return const SizedBox.shrink();
                  }
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
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
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

  // ───────────────────────── helpers ─────────────────────────

  static List<_MonthlyPoint> _buildMonthlyBuckets(
    List<Datum> items, {
    required int monthsBack,
    required PurchasingMetric metric,
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

      final add = (metric == PurchasingMetric.kg)
          ? _parseKg(d.quantity)
          : _moneyValue(d);
      map[key] = (map[key] ?? 0) + add;
    }

    return months
        .map((m) => _MonthlyPoint(month: m, value: map[_monthKey(m)] ?? 0))
        .toList();
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static double _parseKg(String? qty) {
    if (qty == null || qty.trim().isEmpty) return 0;
    final cleaned = qty
        .replaceAll(RegExp('[^0-9,\\.]'), '')
        .replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    return (v == null || v.isNaN || v.isInfinite) ? 0 : v;
  }

  static double _moneyValue(Datum d) {
    final net = d.netPayment ?? d.valuePurchased;
    if (net != null) return net.toDouble();
    final p = (d.pricePerKg ?? 0).toDouble();
    final q = _parseKg(d.quantity);
    return p * q;
  }

  static String _monthLabel(DateTime month, String lang) {
    const en = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const id = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final arr = lang == 'id' ? id : en;
    return '${arr[month.month - 1]} ${month.year % 100}';
  }

  // Short axis labels
  static String _fmtKgShort(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}t';
    return '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}kg';
  }

  static String _fmtMoneyShort(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}M';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}jt';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  // Tooltip full labels
  static String _fmtKgFull(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} ton';
    return '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kg';
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

/// Produces a “nice” max and tick step so the top title aligns perfectly.
class _Scale {
  final double max;
  final double step;
  const _Scale(this.max, this.step);
}

/// Nice-number scaling (like d3/Chart.js). Ensures top tick is reached cleanly.
_Scale _niceScale(double rawMax, int maxTicks, {int base = 10}) {
  // Edge case: no data
  if (rawMax <= 0 || rawMax.isNaN || rawMax.isInfinite)
  {
    return const _Scale(1, 0.25);
  }
  final exponent = (math.log(rawMax) / math.log(base)).floor();
  final fraction = rawMax / math.pow(base, exponent);

  double niceFraction;
  if (fraction <= 1) {
    niceFraction = 1;
  } else if (fraction <= 2)
  {
    niceFraction = 2;
  }
  else if (fraction <= 5)
  {
    niceFraction = 5;
  }
  else
  {
    niceFraction = 10;
  }

  final niceMax = niceFraction * math.pow(base, exponent).toDouble();

  // Compute step from desired tick count; clamp to a “nice” step as well
  final desiredStep = niceMax / (maxTicks - 1);
  final stepExp = (math.log(desiredStep) / math.log(base)).floor();
  final stepFrac = desiredStep / math.pow(base, stepExp);

  double niceStepFrac;
  if (stepFrac <= 1) {
    niceStepFrac = 1;
  } else if (stepFrac <= 2)
  {
    niceStepFrac = 2;
  }
  else if (stepFrac <= 5)
  {
    niceStepFrac = 5;
  }
  else
  {
    niceStepFrac = 10;
  }

  final niceStep = niceStepFrac * math.pow(base, stepExp).toDouble();

  // Make sure max is a multiple of step
  final topTicks = (niceMax / niceStep).round();
  final finalMax = niceStep * topTicks;

  return _Scale(finalMax, niceStep);
}

class _MonthlyPoint {
  final DateTime month;
  final double value;
  _MonthlyPoint({required this.month, required this.value});
}
