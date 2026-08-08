import 'package:flutter/material.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeOfflineBanner extends StatelessWidget {
  final bool isID;
  final bool isSyncing;
  final VoidCallback onSync;

  const TreeOfflineBanner({
    super.key,
    required this.isID,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isID
                  ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                  : 'Offline mode: showing the last saved data.',
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: isSyncing ? null : onSync,
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(
              isSyncing
                  ? (isID ? 'Menyinkron...' : 'Syncing...')
                  : (isID ? 'Sinkron' : 'Sync'),
            ),
          ),
        ],
      ),
    );
  }
}
