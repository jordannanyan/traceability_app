import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PolygonTopInfoBar extends StatelessWidget {
  final KthPolygonController c;
  final BuildContext ctx;

  const PolygonTopInfoBar({super.key, required this.c, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final wkt = c.buildWkt();
      final valid = wkt.isNotEmpty;

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              bottom:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.darkestGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.polyline,
                      color: ThemeColor.darkestGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isID
                        ? 'Tambah titik lewat tombol, foto + GPS otomatis'
                        : 'Add a point with the button — photo + GPS captured automatically',
                    style: ThemeTextStyle
                        .textStyleForthBold
                        .copyWith(fontSize: 14),
                  ),
                ),
                if (c.isLoading.value)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: valid
                          ? Colors.green.withValues(alpha: 0.10)
                          : Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.xl),
                      border: Border.all(
                        color: valid
                            ? Colors.green.withValues(alpha: 0.20)
                            : Colors.orange.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      valid ? 'Valid' : (isID ? 'Belum valid' : 'Not yet valid'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: valid
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  isID
                      ? 'Titik: ${c.points.length}'
                      : 'Points: ${c.points.length}',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  isID ? 'Min 3 titik' : 'Min 3 points',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 12),
                ),
                const Spacer(),
                if (c.points.isNotEmpty)
                  TextButton.icon(
                    onPressed: c.isLoading.value
                        ? null
                        : () => c.showPointsSheet(ctx),
                    icon: const Icon(Icons.list, size: 16),
                    label: Text(isID ? 'Detail' : 'Details'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Text(
                wkt.isEmpty ? 'WKT: -' : 'WKT: $wkt',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }
}
