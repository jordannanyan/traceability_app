import 'package:flutter/material.dart';

import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class GudangHeaderSection extends StatelessWidget {
  final bool isID;
  final int count;
  final String lastSync;

  const GudangHeaderSection({
    super.key,
    required this.isID,
    required this.count,
    required this.lastSync,
  });

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
                    color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(
                    Icons.warehouse_outlined,
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
                        isID ? 'Informasi Gudang' : 'Warehouse Information',
                        style: ThemeTextStyle.textStyleForthBold.copyWith(
                              fontSize: 20,
                              color: ThemeColor.darkestGreen,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isID
                            ? 'Kelola dan pantau gudang penyimpanan'
                            : 'Manage and monitor storage warehouses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  (isID ? 'Terakhir sinkron: ' : 'Last sync: ') + lastSync,
                  style: ThemeTextStyle.textStyleForthBold.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(
                  color: ThemeColor.darkestGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: ThemeColor.darkestGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isID ? '$count Gudang Terdaftar' : '$count Warehouses',
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
