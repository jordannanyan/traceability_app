import 'package:flutter/material.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/themes/app_tokens.dart';

/// Marks a list row that exists only in the outbox, or whose queued change has
/// not reached the server yet.
///
/// The counterpart of the screen-level `OfflineBanner`: the banner says *this
/// whole screen is showing saved data*, this badge says *this particular row is
/// still waiting to be uploaded*. Rows carrying it are not editable — see the
/// callers, which show a "waiting for sync" message on tap instead.
class PendingSyncBadge extends StatelessWidget {
  final PendingOpKind kind;
  final bool isID;

  /// Drops the icon and shrinks the padding, for dense rows.
  final bool compact;

  const PendingSyncBadge({
    super.key,
    required this.kind,
    required this.isID,
    this.compact = false,
  });

  String get _label {
    switch (kind) {
      case PendingOpKind.create:
        return 'Offline';
      case PendingOpKind.update:
        return isID ? 'Offline · edit' : 'Offline · edited';
      case PendingOpKind.delete:
        return isID ? 'Offline · hapus' : 'Offline · delete';
    }
  }

  /// A queued delete reads as destructive, so it gets its own colour instead of
  /// the amber "waiting" treatment.
  bool get _isDelete => kind == PendingOpKind.delete;

  @override
  Widget build(BuildContext context) {
    final bg = _isDelete ? Colors.red.shade50 : Colors.amber.shade100;
    final border = _isDelete ? Colors.red.shade200 : Colors.amber.shade300;
    final fg = _isDelete ? Colors.red.shade700 : Colors.brown;

    return Tooltip(
      message: isID
          ? 'Tersimpan di perangkat, menunggu sinkron ke server.'
          : 'Saved on this device, waiting to sync to the server.',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(
                _isDelete ? Icons.delete_forever : Icons.cloud_upload_outlined,
                size: 12,
                color: fg,
              ),
              const SizedBox(width: 4),
            ],
            // Flexible + ellipsis: in a tight row (long neighbouring title, or
            // a large text scale) the label shortens instead of painting the
            // overflow stripes. The Row still hugs its content when there is
            // room, because of mainAxisSize.min above.
            Flexible(
              child: Text(
                _label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar shown when a user taps a row that is still queued. Opening such a
/// row is not possible: it has no server id yet (create) or the server copy is
/// stale relative to what is queued (update/delete).
void showPendingRowMessage(BuildContext context, {required bool isID}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          isID
              ? 'Data ini masih menunggu sinkron. Sambungkan internet lalu tekan Sync.'
              : 'This record is still waiting to sync. Go online, then tap Sync.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}
