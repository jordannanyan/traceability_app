import 'dart:io';

import 'package:flutter/material.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/tree_monitoring.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
const String _kStorageBaseUrl =
    'https://app.nbsvworldwide.com';

String? _resolvePhotoUrl(String? v) {
  if (v == null) return null;
  String s = v.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);
    if (u == null) return s;
    if (u.host == 'localhost' || u.host == '127.0.0.1') {
      return Uri(
        scheme: 'https',
        host: 'app.nbsvworldwide.com',
        path: u.path,
      ).toString();
    }
    return s;
  }
  // Normalise relative path: strip leading slashes and ensure single `storage/` prefix.
  // DB may store `/storage/trees/x.jpg`, `storage/trees/x.jpg`, `/trees/x.jpg`, or `trees/x.jpg`.
  s = s.replaceFirst(RegExp(r'^/+'), '');
  if (!s.startsWith('storage/')) {
    s = 'storage/$s';
  }
  return '$_kStorageBaseUrl/$s';
}

class TreeMonitoringList extends StatelessWidget {
  final List<TreeMonitoring> items;
  final String language;
  final Future<void> Function(BuildContext, int) onDelete;
  final List<int> deleting;
  final int indexOffset;

  /// Pending (outbox) state per row id — rows not in it are fully synced.
  final PendingOpKind? Function(int? id)? pendingKindFor;

  const TreeMonitoringList({
    super.key,
    required this.items,
    required this.language,
    required this.onDelete,
    required this.deleting,
    this.indexOffset = 0,
    this.pendingKindFor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            language == 'id'
                ? 'Belum ada monitoring.'
                : 'No monitoring yet.',
            style: ThemeTextStyle
                .textStyleForthBold
                .copyWith(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final id = item.id ?? 0;
        final isDeleting = id != 0 && deleting.contains(id);
        return TreeMonitoringCard(
          item: item,
          language: language,
          isDeleting: isDeleting,
          pendingKind: pendingKindFor?.call(item.id),
          onDelete: id == 0
              ? null
              : () => onDelete(context, id),
        );
      },
    );
  }
}

class TreeMonitoringCard extends StatelessWidget {
  final TreeMonitoring item;
  final String language;
  final bool isDeleting;
  final VoidCallback? onDelete;

  /// Non-null when this row is still queued in the outbox.
  final PendingOpKind? pendingKind;

  const TreeMonitoringCard({
    super.key,
    required this.item,
    required this.language,
    required this.isDeleting,
    required this.onDelete,
    this.pendingKind,
  });

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final isID = language == 'id';
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            isID ? 'Hapus monitoring?' : 'Delete monitoring?'),
        content: Text(
          isID
              ? 'Data yang dihapus tidak bisa dikembalikan. Lanjutkan?'
              : 'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isID ? 'Batal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isID ? 'Hapus' : 'Delete'),
          ),
        ],
      ),
    );
    return res == true;
  }

  /// A queued row's `photo_path` is still a local file, not a server path, so
  /// it has to be read from disk instead of being turned into a URL.
  File? get _localPhoto {
    final p = item.photoPath;
    if (p == null || p.trim().isEmpty) return null;
    final f = File(p);
    return f.existsSync() ? f : null;
  }

  @override
  Widget build(BuildContext context) {
    final isID = language == 'id';
    final localPhoto = _localPhoto;
    final url = localPhoto != null
        ? null
        : (_resolvePhotoUrl(item.photoPath) ?? item.photoUrl);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: localPhoto != null
                    ? Image.file(
                        localPhoto,
                        fit: BoxFit.cover,
                        cacheWidth: 112,
                        cacheHeight: 112,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.green.withValues(alpha: 0.12),
                          child: const Icon(Icons.nature, size: 28),
                        ),
                      )
                    : url == null
                    ? Container(
                        color: Colors.green
                            .withValues(alpha: 0.12),
                        child: const Icon(Icons.nature,
                            size: 28),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        cacheWidth: 112,
                        cacheHeight: 112,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) =>
                            Container(
                          color: Colors.green
                              .withValues(alpha: 0.12),
                          child: const Icon(
                              Icons.broken_image),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isID
                              ? 'Data Monitoring'
                              : 'Monitoring Data',
                          style: ThemeTextStyle
                              .textStyleForthBold
                              .copyWith(
                                color: ThemeColor.darkestGreen,
                                fontSize: 13,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pendingKind != null) ...[
                        const SizedBox(width: Insets.sm),
                        PendingSyncBadge(
                          kind: pendingKind!,
                          isID: isID,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _row(
                    Icons.event_available_outlined,
                    isID ? 'Waktu' : 'Measured At',
                    _fmtDateTime(item.measuredAt),
                  ),
                  const SizedBox(height: 4),
                  _row(
                    Icons.local_hospital_outlined,
                    isID ? 'Kesehatan' : 'Health',
                    item.healthStatus ?? '-',
                  ),
                  const SizedBox(height: 4),
                  _row(
                    Icons.straighten,
                    isID
                        ? 'Keliling (cm)'
                        : 'Circumference (cm)',
                    (item.circumferenceCm?.isNotEmpty ?? false)
                        ? '${item.circumferenceCm}'
                        : '-',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: isID ? 'Hapus' : 'Delete',
              onPressed: (onDelete == null || isDeleting)
                  ? null
                  : () async {
                      final ok =
                          await _confirmDelete(context);
                      if (!ok) return;
                      onDelete!.call();
                    },
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    )
                  : Icon(Icons.delete_outline,
                      color: Colors.red.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
