import 'package:flutter/material.dart';
import 'package:traceability_app/screens/widgets/offline_banner.dart';
import 'package:traceability_app/themes/app_tokens.dart';

/// Curved green header used at the top of the KTH and Farmer home screens.
///
/// Renders greeting + display name, last-sync info, an offline badge when
/// applicable, and a "Quick Menu" row of [QuickActionTile]s supplied by the
/// caller (either scrollable horizontally or fixed-width spread).
class HomeGreenHeader extends StatelessWidget {
  final bool isID;
  final String name;

  /// Fallback display name when [name] is empty (e.g. "Partner" or "Petani").
  final String nameFallback;

  final bool isOffline;
  final String lastSync;

  /// Quick action row built by the caller — typically a [Row] of
  /// [QuickActionTile]s, optionally wrapped in a horizontal scroll view.
  final Widget quickActions;

  const HomeGreenHeader({
    super.key,
    required this.isID,
    required this.name,
    required this.nameFallback,
    required this.isOffline,
    required this.lastSync,
    required this.quickActions,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (isID) {
      if (hour < 12) return 'Selamat Pagi';
      if (hour < 15) return 'Selamat Siang';
      if (hour < 18) return 'Selamat Sore';
      return 'Selamat Malam';
    } else {
      if (hour < 12) return 'Good Morning';
      if (hour < 18) return 'Good Afternoon';
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D6B2E), Color(0xFF169843)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.isNotEmpty ? name : nameFallback,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOffline) const OfflineBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 4),
              Text(
                (isID ? 'Terakhir sinkron: ' : 'Last sync: ') + lastSync,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isID ? 'Menu Cepat' : 'Quick Menu',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          quickActions,
        ],
      ),
    );
  }
}

/// Single icon tile used inside [HomeGreenHeader.quickActions].
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Right-side padding — set to zero for the last item in a scrolling row.
  final double trailingSpace;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingSpace = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: trailingSpace),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
