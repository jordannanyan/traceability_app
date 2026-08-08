import 'package:traceability_app/services/language_service.dart';

/// Translates known Indonesian API/result messages to the active app language.
///
/// Many APIs return hardcoded Indonesian strings (e.g. for offline-first
/// fallbacks) or pass through server messages. This helper maps the common
/// patterns to English when the user has set the app language to English, and
/// returns the original message otherwise.
///
/// Usage:
/// ```dart
/// final msg = tr(res.message);
/// ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
/// ```
String tr(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return s;
  if (LanguageService.to.isId) return s;

  // Exact-match table for known hardcoded messages.
  const exact = <String, String>{
    // Generic offline queue
    'Tersimpan offline. Akan disinkronkan saat online.':
        'Saved offline. Will sync when online.',
    'Perubahan disimpan offline. Akan disinkronkan saat online.':
        'Changes saved offline. Will sync when online.',
    'Penghapusan disimpan offline. Akan disinkronkan saat online.':
        'Deletion saved offline. Will sync when online.',
    'Tersimpan offline. Akan diunggah saat online.':
        'Saved offline. Will upload when online.',
    'Perubahan disimpan offline. Akan diunggah saat online.':
        'Changes saved offline. Will upload when online.',
    'Penghapusan disimpan offline. Akan diunggah saat online.':
        'Deletion saved offline. Will upload when online.',

    // Polygon / photos
    'Polygon disimpan offline. Akan disinkronkan saat online.':
        'Polygon saved offline. Will sync when online.',
    'Foto disimpan offline. Akan diunggah saat online.':
        'Photo saved offline. Will upload when online.',

    // Monitoring
    'Monitoring disimpan offline. Akan diunggah saat online.':
        'Monitoring saved offline. Will upload when online.',
    'Perubahan monitoring disimpan offline. Akan diunggah saat online.':
        'Monitoring changes saved offline. Will upload when online.',
    'Penghapusan monitoring disimpan offline. Akan diunggah saat online.':
        'Monitoring deletion saved offline. Will upload when online.',

    // Common short server messages
    'Berhasil': 'Success',
    'Berhasil disimpan': 'Saved successfully',
    'Berhasil diperbarui': 'Updated successfully',
    'Berhasil dihapus': 'Deleted successfully',
    'Data berhasil disimpan': 'Data saved successfully',
    'Data berhasil diperbarui': 'Data updated successfully',
    'Data berhasil dihapus': 'Data deleted successfully',
    'Gagal menyimpan': 'Failed to save',
    'Gagal memperbarui': 'Failed to update',
    'Gagal menghapus': 'Failed to delete',
    'Tidak ada koneksi internet': 'No internet connection',

    // Tree CRUD result messages
    'Pohon ditambahkan.': 'Tree added.',
    'Pohon diperbarui.': 'Tree updated.',
    'Pohon dihapus.': 'Tree deleted.',
    'Pohon dihapus': 'Tree deleted.',
  };

  // "Tersinkron: <N> aksi tertunda." → "Synced: <N> pending action(s)."
  final syncedMatch =
      RegExp(r'^Tersinkron:\s*(\d+)\s*aksi tertunda\.?$').firstMatch(s);
  if (syncedMatch != null) {
    final n = syncedMatch.group(1);
    return 'Synced: $n pending action(s).';
  }

  final exactHit = exact[s];
  if (exactHit != null) return exactHit;

  // Lightweight pattern fallbacks for variants ("Foo disimpan offline. ..."):
  final lower = s.toLowerCase();
  if (lower.contains('disimpan offline') &&
      lower.contains('akan disinkronkan saat online')) {
    return 'Saved offline. Will sync when online.';
  }
  if (lower.contains('disimpan offline') &&
      lower.contains('akan diunggah saat online')) {
    return 'Saved offline. Will upload when online.';
  }

  // Unknown — pass through unchanged. UI still shows it; that's better than
  // hiding server error details.
  return s;
}

/// Builds a truthful manual-sync result message from the outbox counts measured
/// around a push.
///
/// [before] = queue size before the push, [pushed] = number the push reported as
/// successfully sent, [after] = queue size after. `pushXOutbox()` returns only
/// the count *successfully* pushed, so a bare `pushed == 0` cannot tell "queue
/// was empty" apart from "queue had items but nothing went through" (all pushes
/// failed on network/5xx, or a concurrent push held the lock). Comparing the
/// counts distinguishes the real outcomes so the UI never falsely says
/// "nothing to sync" while items are still queued.
String syncResultMessage({
  required int before,
  required int pushed,
  required int after,
}) {
  final isID = LanguageService.to.isId;
  if (before <= 0) {
    return isID
        ? 'Tidak ada aksi tertunda untuk disinkronkan.'
        : 'No pending actions to sync.';
  }

  // All synced cleanly.
  if (pushed >= before && after <= 0) {
    return isID
        ? 'Berhasil menyinkronkan $pushed aksi tertunda.'
        : 'Synced $pushed pending action(s).';
  }

  // `cleared` left the queue; whatever wasn't `pushed` was dropped by the server
  // as invalid (4xx poison) — that is data loss the user must be told about.
  final cleared = before - after;
  final dropped = (cleared - pushed).clamp(0, before);
  final parts = <String>[];
  if (isID) {
    if (pushed > 0) parts.add('$pushed tersinkron');
    if (dropped > 0) parts.add('$dropped ditolak server');
    if (after > 0) parts.add('$after masih tertunda');
    if (parts.isEmpty) {
      return 'Gagal menyinkronkan. $before aksi masih tertunda — periksa koneksi lalu coba lagi.';
    }
    return '${parts.join(', ')}.';
  } else {
    if (pushed > 0) parts.add('$pushed synced');
    if (dropped > 0) parts.add('$dropped rejected by server');
    if (after > 0) parts.add('$after still pending');
    if (parts.isEmpty) {
      return 'Sync failed. $before action(s) still pending — check your connection and retry.';
    }
    return '${parts.join(', ')}.';
  }
}
