import 'package:flutter/material.dart';
import 'package:traceability_app/themes/app_tokens.dart';

class OfflineBanner extends StatelessWidget {
  final bool isID;

  /// Optional sync action button (null = no button).
  final VoidCallback? onSync;

  /// Set true while a sync is running to disable the button and show spinner.
  final bool isSyncing;

  /// Outer margin around the banner.
  final EdgeInsetsGeometry margin;

  const OfflineBanner({
    super.key,
    required this.isID,
    this.onSync,
    this.isSyncing = false,
    this.margin = const EdgeInsets.only(bottom: Insets.md),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Colors.brown),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              isID
                  ? 'Mode offline: menampilkan data terakhir tersimpan.'
                  : 'Offline mode: showing the last saved data.',
              style: const TextStyle(fontSize: 13, color: Colors.brown),
            ),
          ),
          if (onSync != null) ...[
            const SizedBox(width: Insets.sm),
            isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.brown,
                    ),
                  )
                : TextButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync, size: 16, color: Colors.brown),
                    label: Text(
                      isID ? 'Sinkron' : 'Sync',
                      style: const TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

/// Small pill-shaped "Offline" badge for use inside headers, cards, etc.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.wifi_off, size: 13, color: Colors.brown),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              color: Colors.brown,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
