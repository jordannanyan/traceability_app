import 'package:flutter/material.dart';

import 'package:traceability_app/themes/theme_text.dart';

class PurchasingHeader extends StatelessWidget {
  final bool isID;
  final String lastSyncText;

  const PurchasingHeader({
    super.key,
    required this.isID,
    required this.lastSyncText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isID ? 'Pembelian Bulanan' : 'Monthly Purchasing',
            style: ThemeTextStyle.textStyleFirstBold,
          ),
        ),
        Row(
          children: [
            const Icon(Icons.history, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              lastSyncText,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
