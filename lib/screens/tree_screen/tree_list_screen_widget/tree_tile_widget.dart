import 'dart:io';

import 'package:flutter/material.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/app_tokens.dart';
import 'package:traceability_app/models/get_trees.dart' as gt;

const String _kStorageBaseUrl =
    'https://app.nbsvworldwide.com';

String? _resolvePhotoUrl(String? v) {
  if (v == null) return null;

  String s = v.trim();

  if (s.isEmpty) return null;

  // Jika sudah full URL
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);

    if (u == null) return s;

    // Replace localhost ke domain production
    if (u.host == 'localhost' || u.host == '127.0.0.1') {
      return Uri(
        scheme: 'https',
        host: 'app.nbsvworldwide.com',
        path: u.path,
      ).toString();
    }

    return s;
  }

  // Hapus slash depan kalau ada
  s = s.replaceFirst(RegExp(r'^/+'), '');

  // Kalau belum ada storage/, tambahkan otomatis
  if (!s.startsWith('storage/')) {
    s = 'storage/$s';
  }

  return '$_kStorageBaseUrl/$s';
}

class TreeTile extends StatelessWidget {
  final gt.Datum data;
  final int index;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;

  /// Non-null when this row is still queued in the outbox — shows the badge.
  final PendingOpKind? pendingKind;
  final bool isID;

  const TreeTile({
    super.key,
    required this.data,
    required this.index,
    required this.onTap,
    this.onDelete,
    this.pendingKind,
    this.isID = true,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 48.0;

    Widget thumb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: const Icon(Icons.nature, size: 28),
    );

    final localPath = data.photoPath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Image.file(
          File(localPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 96,
          cacheHeight: 96,
          errorBuilder: (_, __, ___) => _fallback(size),
        ),
      );
    } else {
      final url = _resolvePhotoUrl(data.photoPath);
      print(url);
      if (url != null && url.isNotEmpty) {
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: 96,
            cacheHeight: 96,
            filterQuality: FilterQuality.low,
            loadingBuilder: (c, child, lp) =>
                lp == null ? child : _loading(size),
            errorBuilder: (_, __, ___) => _fallback(size),
          ),
        );
      }
    }

    String two(int x) => x.toString().padLeft(2, '0');
    final planted = data.plantingDate == null
        ? '-'
        : '${two(data.plantingDate!.day)}-${two(data.plantingDate!.month)}-${data.plantingDate!.year}';

    return ListTile(
      leading: thumb,
      title: Row(
        children: [
          Text(
            index.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (pendingKind != null) ...[
            const SizedBox(width: Insets.sm),
            PendingSyncBadge(kind: pendingKind!, isID: isID, compact: true),
          ],
        ],
      ),
      subtitle: Text(
        '${data.species ?? '-'} • $planted',
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDelete != null)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async => await onDelete!(),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _loading(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _fallback(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.nature, size: 28),
      );
}
