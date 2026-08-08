import 'package:flutter/material.dart';

import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/themes/app_tokens.dart';

/// Says out loud that the screen is showing stored data because the refresh
/// failed — while online.
///
/// Being offline already has its own banner and is expected in the field. What
/// had no signal at all was the other case: online, the refresh rejected or
/// broken, and the stored copy quietly shown as if it were current. That is how
/// an expired session turned into "the list never grows however often I pull to
/// refresh". Render this whenever [CachedResult.needsWarning] is true.
class StaleDataBanner extends StatelessWidget {
  final RefreshOutcome outcome;
  final bool isID;

  /// Retry hook — omitted for [RefreshOutcome.unauthorized], where retrying
  /// cannot help until the user logs in again.
  final VoidCallback? onRetry;

  const StaleDataBanner({
    super.key,
    required this.outcome,
    required this.isID,
    this.onRetry,
  });

  bool get _isAuth => outcome == RefreshOutcome.unauthorized;

  String get _message {
    if (_isAuth) {
      return isID
          ? 'Sesi Anda sudah berakhir, jadi data tidak bisa diperbarui. '
                'Masuk ulang untuk melihat data terbaru.'
          : 'Your session has expired, so the data could not be refreshed. '
                'Log in again to see current data.';
    }
    return isID
        ? 'Gagal memuat data terbaru. Yang tampil adalah data tersimpan.'
        : 'Could not load the latest data. Showing the stored copy.';
  }

  @override
  Widget build(BuildContext context) {
    if (outcome != RefreshOutcome.refreshFailed &&
        outcome != RefreshOutcome.unauthorized) {
      return const SizedBox.shrink();
    }

    final bg = _isAuth ? const Color(0xFFFDEAEA) : const Color(0xFFFFF5CC);
    final border = _isAuth ? const Color(0xFFF3B7B7) : const Color(0xFFFFE08A);
    final fg = _isAuth ? const Color(0xFFB02121) : Colors.brown;

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            _isAuth ? Icons.lock_clock : Icons.sync_problem,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(fontSize: 13, color: fg),
            ),
          ),
          if (!_isAuth && onRetry != null) ...[
            const SizedBox(width: Insets.sm),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              ),
              child: Text(
                isID ? 'Coba lagi' : 'Retry',
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
