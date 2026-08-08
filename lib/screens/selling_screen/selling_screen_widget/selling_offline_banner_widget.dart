import 'package:flutter/material.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SellingOfflineBanner extends StatelessWidget {
  final bool isID;
  final bool isSyncing;
  final VoidCallback onSync;

  const SellingOfflineBanner({
    super.key,
    required this.isID,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isID
                  ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                  : 'Offline mode: showing the last saved data.',
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: isSyncing ? null : onSync,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: isSyncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(
              isSyncing
                  ? (isID ? 'Menyinkron...' : 'Syncing...')
                  : (isID ? 'Sinkron' : 'Sync'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
