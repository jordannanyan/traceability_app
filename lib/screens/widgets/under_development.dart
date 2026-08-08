import 'package:flutter/material.dart';

import 'package:traceability_app/themes/app_tokens.dart';
import 'package:traceability_app/themes/theme_color.dart';

/// Placeholder for a menu that is closed while the backend is reworked.
///
/// Purchasing, processing and selling moved to a new database structure, and
/// the endpoints this app used for them (`/purchasing/kth/:id`,
/// `/purchasing/farmer/:id`, `/selling/kth/:id`) no longer exist — they answer
/// 404. Leaving the old screens in place meant showing months-old cached rows
/// as if they were current, which is worse than showing nothing: it is data
/// people could act on. These screens stay reachable, but say plainly that they
/// are being rebuilt.
class UnderDevelopment extends StatelessWidget {
  final bool isID;

  /// Nama menu, mis. "Pembelian" — dipakai di kalimat penjelas.
  final String featureName;

  /// Kalimat tambahan opsional, mis. ke mana harus melihat data untuk sementara.
  final String? note;

  const UnderDevelopment({
    super.key,
    required this.isID,
    required this.featureName,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final defaultNote = isID
        ? 'Menu ini sedang disesuaikan dengan struktur data baru '
              '(pembelian, processing, dan penjualan). Untuk sementara, '
              'data $featureName dilihat melalui sistem kantor.'
        : 'This menu is being reworked for the new data structure '
              '(purchasing, processing and selling). For now, '
              '$featureName data is available in the office system.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: ThemeColor.darkestGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction_outlined,
                size: 44,
                color: ThemeColor.darkestGreen,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              isID ? 'Sedang dalam pengembangan' : 'Under development',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ThemeColor.darkestGreen,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              note ?? defaultNote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Versi ringkas untuk dipakai sebagai kartu di dalam beranda.
class UnderDevelopmentCard extends StatelessWidget {
  final bool isID;
  final String featureName;

  const UnderDevelopmentCard({
    super.key,
    required this.isID,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.construction_outlined,
            size: 26,
            color: ThemeColor.darkestGreen.withValues(alpha: 0.7),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            isID
                ? '$featureName sedang dalam pengembangan'
                : '$featureName is under development',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isID
                ? 'Menyesuaikan struktur data baru.'
                : 'Being reworked for the new data structure.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
