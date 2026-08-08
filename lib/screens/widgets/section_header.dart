import 'package:flutter/material.dart';
import 'package:traceability_app/themes/theme_color.dart';

/// Section header with title on the left and an optional "View All" link on
/// the right. Used on home screens between sections.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? viewMoreLabel;
  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.viewMoreLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (viewMoreLabel != null && onTap != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              viewMoreLabel!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThemeColor.darkestGreen,
              ),
            ),
          ),
      ],
    );
  }
}
