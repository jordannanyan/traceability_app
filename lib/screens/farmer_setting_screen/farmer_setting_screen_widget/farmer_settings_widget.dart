import 'package:flutter/material.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
/// Header card with avatar, name, role (+ optional KTH subtitle)
class HeaderCard extends StatelessWidget {
  final String name;
  final String role; // e.g. 'Petani' / 'Farmer'
  final String? subtitle; // e.g. 'KTH: ...'
  final String? photoPrimaryUrl;
  final String? photoFallbackUrl;

  const HeaderCard({
    super.key,
    required this.name,
    required this.role,
    this.subtitle,
    this.photoPrimaryUrl,
    this.photoFallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Avatar(primaryUrl: photoPrimaryUrl, fallbackUrl: photoFallbackUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ThemeTextStyle.textStyleForthBold.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.agriculture, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            role, // <-- dynamic, bukan hard-coded lagi
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circle avatar with primary → fallback → placeholder (stateless, crash-safe)
class Avatar extends StatelessWidget {
  final String? primaryUrl;
  final String? fallbackUrl;

  const Avatar({super.key, required this.primaryUrl, required this.fallbackUrl});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ThemeColor.darkestGreen.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.person, size: 36, color: Colors.white),
        );

    Widget asImage(String url, {required Widget Function() onError}) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, evt) =>
                evt == null ? child : Container(color: Colors.grey.shade200),
            errorBuilder: (ctx, err, st) => onError(),
          ),
        ),
      );
    }

    // no image at all
    if ((primaryUrl == null || primaryUrl!.isEmpty) &&
        (fallbackUrl == null || fallbackUrl!.isEmpty)) {
      return placeholder();
    }

    // primary first, then fallback, then placeholder
    if (primaryUrl != null && primaryUrl!.isNotEmpty) {
      return asImage(
        primaryUrl!,
        onError: () {
          if (fallbackUrl != null && fallbackUrl!.isNotEmpty) {
            return asImage(fallbackUrl!, onError: placeholder);
          }
          return placeholder();
        },
      );
    }

    // only fallback available
    return asImage(fallbackUrl!, onError: placeholder);
  }
}

/// Section wrapper card
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: ThemeTextStyle.textStyleForthBold.copyWith(
                    color: ThemeColor.darkestGreen,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// Reusable settings tile
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ThemeColor.darkestGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, color: iconColor ?? ThemeColor.darkestGreen),
      ),
      title: Text(
        title,
        style: ThemeTextStyle.textStyleForthBold.copyWith(
              color: titleColor ?? Colors.black,
            ),
      ),
      subtitle: (subtitle != null && subtitle!.trim().isNotEmpty)
          ? Text(subtitle!, style: const TextStyle(color: Colors.grey))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}

// DB stores photo paths inconsistently: `/storage/foo.jpg`, `storage/foo.jpg`,
// `/foo.jpg`, or `foo.jpg`. Normalise to a single `storage/` prefix.
String? buildPhotoUrlPrimary(dynamic foto) {
  if (foto == null) return null;
  String s = foto.toString().trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  s = s.replaceFirst(RegExp(r'^/+'), '');
  if (!s.startsWith('storage/')) {
    s = 'storage/$s';
  }
  return 'https://app.nbsvworldwide.com/$s';
}

String? buildPhotoUrlFallback(dynamic foto) => null;
