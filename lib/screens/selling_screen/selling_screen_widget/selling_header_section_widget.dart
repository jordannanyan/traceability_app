import 'package:flutter/material.dart';

import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SellingHeaderSection extends StatelessWidget {
  final bool isID;
  final int count;
  final String lastSyncText;

  const SellingHeaderSection({
    super.key,
    required this.isID,
    required this.count,
    required this.lastSyncText,
  });

  @override
  Widget build(BuildContext context) {
    final darkest = ThemeColor.darkestGreen;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkest.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: darkest.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: darkest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isID ? 'Informasi Penjualan' : 'Selling Information',
                        style: ThemeTextStyle.textStyleForthBold.copyWith(
                              fontSize: 16,
                              color: darkest,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isID
                            ? 'Ringkasan penjualan & riwayat transaksi'
                            : 'Sales summary & transaction history',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lastSyncText,
                    style: ThemeTextStyle.textStyleForthBold.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: darkest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: darkest.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 14, color: darkest),
                  const SizedBox(width: 6),
                  Text(
                    isID ? '$count Transaksi' : '$count Transactions',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: darkest,
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
