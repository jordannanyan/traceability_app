import 'package:flutter/material.dart';

import 'package:traceability_app/screens/tree_screen/tree_screen_controller.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
// ====== Avatar initials ======
class TreeAvatarInitials extends StatelessWidget {
  final String name;
  const TreeAvatarInitials({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    String initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((e) => e.isEmpty ? '' : e[0]).join();
    initials = initials.toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor:
          ThemeColor.darkestGreen.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}

// ====== Plot count pill ======
class TreePlotCountPill extends StatelessWidget {
  final int? count;
  const TreePlotCountPill({super.key, this.count});

  @override
  Widget build(BuildContext context) {
    final text = count == null ? '...' : '$count plot';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style:
            const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

// ====== Plot list tile ======
class TreePlotListTile extends StatelessWidget {
  final PlotLite plot;
  final bool isID;
  final VoidCallback onTap;

  const TreePlotListTile({
    super.key,
    required this.plot,
    required this.isID,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String coordText = (plot.latitude != null &&
            plot.longitude != null &&
            plot.latitude!.isNotEmpty &&
            plot.longitude!.isNotEmpty)
        ? 'Lat: ${plot.latitude}, Lng: ${plot.longitude}'
        : (isID ? 'Tanpa koordinat' : 'No coordinates');

    String? infoText;
    final hasArea = plot.landArea != null && plot.landArea!.isNotEmpty;
    final hasPlants = plot.numberOfPlants != null;

    if (hasArea && hasPlants) {
      infoText = isID
          ? 'Luas: ${plot.landArea} ha • Tanaman: ${plot.numberOfPlants}'
          : 'Area: ${plot.landArea} ha • Plants: ${plot.numberOfPlants}';
    } else if (hasArea) {
      infoText = isID
          ? 'Luas: ${plot.landArea} ha'
          : 'Area: ${plot.landArea} ha';
    } else if (hasPlants) {
      infoText = isID
          ? 'Tanaman: ${plot.numberOfPlants}'
          : 'Plants: ${plot.numberOfPlants}';
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined),
      ),
      title: Text(plot.code),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coordText,
            style:
                const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if (infoText != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                infoText,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 12),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
