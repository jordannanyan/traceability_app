import 'package:flutter/material.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeListQueueBar extends StatelessWidget {
  final bool isID;
  final bool isOffline;
  final bool syncing;
  final int outboxTotal;
  final int syncDone;
  final String? syncError;
  final VoidCallback onSync;
  final VoidCallback onRefresh;

  const TreeListQueueBar({
    super.key,
    required this.isID,
    required this.isOffline,
    required this.syncing,
    required this.outboxTotal,
    required this.syncDone,
    this.syncError,
    required this.onSync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasQueue = outboxTotal > 0;
    final show = hasQueue || syncing || (syncError != null);
    if (!show) return const SizedBox.shrink();

    final online = !isOffline;
    final subtitle = isID
        ? (online
            ? 'Online, data offline akan diunggah. Tekan Sync bila perlu.'
            : 'Offline, aksi disimpan di perangkat.')
        : (online
            ? 'Online, offline data will be uploaded. Tap Sync if needed.'
            : 'Offline, actions are stored on device.');

    final progressValue = (outboxTotal <= 0)
        ? 0.0
        : (syncDone / outboxTotal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            online ? const Color(0xFFEFF6FF) : const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: online
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFFFE08A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                syncing
                    ? Icons.cloud_upload
                    : (online ? Icons.cloud_done : Icons.wifi_off),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Offline Queue',
                  style:
                      TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  isID
                      ? '$outboxTotal item'
                      : '$outboxTotal item(s)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: (!online || syncing) ? null : onSync,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
                color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),

          if (online && outboxTotal > 0) ...[
            LinearProgressIndicator(
              minHeight: 6,
              value: syncing ? null : progressValue,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    syncing
                        ? (isID ? 'Mengunggah...' : 'Uploading...')
                        : (isID
                            ? 'Terunggah: $syncDone/$outboxTotal'
                            : 'Uploaded: $syncDone/$outboxTotal'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: syncing ? null : onRefresh,
                  child: Text(isID ? 'Refresh' : 'Refresh'),
                ),
              ],
            ),
          ],

          if (syncError != null) ...[
            const SizedBox(height: 6),
            Text(
              isID
                  ? 'Terakhir gagal: $syncError'
                  : 'Last error: $syncError',
              style: const TextStyle(
                  color: Colors.red, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
