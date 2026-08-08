import 'package:flutter/material.dart';

import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as plot_list;
import 'package:traceability_app/screens/lahan_screen/lahan_screen_widget/plot_map_widget.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PlotInfoHeader extends StatelessWidget {
  final String lastSync;
  final List<plot_list.Datum> plots;

  const PlotInfoHeader({super.key, required this.lastSync, required this.plots});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeColor.darkestGreen.withValues(alpha: 0.1),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.darkestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(
                    Icons.agriculture_outlined,
                    color: ThemeColor.darkestGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Plot',
                        style:
                            ThemeTextStyle.textStyleForthBold.copyWith(
                          fontSize: 20,
                          color: ThemeColor.darkestGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola dan pantau plot pertanian',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Terakhir sinkron: $lastSync',
                  style: ThemeTextStyle.textStyleForthBold.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PlotMapFlutterMap(plots: plots),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    ThemeColor.darkestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(
                  color: ThemeColor
                      .darkestGreen
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco_outlined,
                    size: 16,
                    color: ThemeColor.darkestGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${plots.length} Plot Terdaftar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.darkestGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
