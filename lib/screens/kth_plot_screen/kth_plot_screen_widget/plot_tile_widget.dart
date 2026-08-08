import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as plot_list;
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_controller.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
// ---------------------------------------------------------------------------
// PlotCard — individual card used in the redesigned KthPlotScreen
// ---------------------------------------------------------------------------

class PlotCard extends StatelessWidget {
  final plot_list.Datum item;
  final int idx;
  final KthPlotController c;
  final BuildContext ctx;

  const PlotCard({
    super.key,
    required this.item,
    required this.idx,
    required this.c,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final name = (item.plotName ?? '').trim();
      // A queued plot has a synthetic negative id, which must never be shown.
      final id = item.id;
      final displayName =
          name.isEmpty ? 'Plot ${(id != null && id > 0) ? id : (idx + 1)}' : name;
      final area = (item.landArea?.toString() ?? '').trim();
      final plants = item.numberOfPlants;
      final hasPoly = (item.polygonWkt ?? '').trim().isNotEmpty;
      final pendingKind = c.pendingKindFor(id);

      return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => c.goPolygon(ctx, item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D6B2E), Color(0xFF169843)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: const Icon(Icons.terrain,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pendingKind != null) ...[
                            const SizedBox(width: Insets.sm),
                            PendingSyncBadge(
                              kind: pendingKind,
                              isID: isID,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                      if (area.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _PlotInfoRow(
                            icon: Icons.straighten_outlined,
                            text: isID ? 'Luas: $area' : 'Area: $area'),
                      ],
                      if (plants != null) ...[
                        const SizedBox(height: 2),
                        _PlotInfoRow(
                            icon: Icons.eco_outlined,
                            text: isID
                                ? '$plants Tanaman'
                                : '$plants Plants'),
                      ],
                      const SizedBox(height: 6),
                      // Polygon status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasPoly
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(Radii.xl),
                          border: Border.all(
                            color: hasPoly
                                ? Colors.green.shade300
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasPoly
                                  ? Icons.polyline
                                  : Icons.polyline_outlined,
                              size: 12,
                              color: hasPoly
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasPoly
                                  ? 'Polygon ✓'
                                  : (isID ? 'Belum ada polygon' : 'No polygon yet'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: hasPoly
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions menu
                PopupMenuButton<String>(
                  icon:
                      Icon(Icons.more_vert, color: Colors.grey.shade400),
                  onSelected: (v) async {
                    if (v == 'polygon') {
                      await c.goPolygon(ctx, item);
                    } else if (v == 'edit') {
                      await c.goEditPlot(ctx, item);
                    } else if (v == 'saprodi') {
                      await c.goSaprodi(ctx, item);
                    } else if (v == 'delete') {
                      await c.confirmDelete(ctx, item);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'polygon',
                      child: Row(children: [
                        const Icon(Icons.polyline, size: 18),
                        const SizedBox(width: 10),
                        Text(isID ? 'Tambah / Edit Polygon' : 'Add / Edit Polygon'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(isID ? 'Edit Plot' : 'Edit Plot'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'saprodi',
                      child: Row(children: [
                        Icon(Icons.grass_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Saprodi'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 10),
                        Text(isID ? 'Hapus' : 'Delete',
                            style: const TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    });
  }
}

class _PlotInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PlotInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class PlotTile extends StatelessWidget {
  final plot_list.Datum item;
  final int idx;
  final KthPlotController c;
  final BuildContext ctx;

  const PlotTile({
    super.key,
    required this.item,
    required this.idx,
    required this.c,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final name = (item.plotName ?? '').trim();
      final subtitleParts = <String>[];

      if (item.landArea != null &&
          item.landArea.toString().trim().isNotEmpty) {
        subtitleParts.add(isID ? 'Luas: ${item.landArea}' : 'Area: ${item.landArea}');
      }
      if (item.numberOfPlants != null) {
        subtitleParts.add(isID
            ? 'Tanaman: ${item.numberOfPlants}'
            : 'Plants: ${item.numberOfPlants}');
      }

      final hasPoly = (item.polygonWkt ?? '').trim().isNotEmpty;
      subtitleParts.add(hasPoly ? 'Polygon: \u2713' : 'Polygon: -');

      final subtitle =
          subtitleParts.isEmpty ? '-' : subtitleParts.join(' \u2022 ');

      return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ThemeColor.darkestGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.map_outlined,
          color: ThemeColor.darkestGreen,
        ),
      ),
      title: Text(
        name.isEmpty ? 'Plot ${item.id ?? (idx + 1)}' : name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'polygon') {
            await c.goPolygon(ctx, item);
          } else if (v == 'edit') {
            await c.goEditPlot(ctx, item);
          } else if (v == 'saprodi') {
            await c.goSaprodi(ctx, item);
          } else if (v == 'delete') {
            await c.confirmDelete(ctx, item);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'polygon',
            child: Row(
              children: [
                const Icon(Icons.polyline, size: 18),
                const SizedBox(width: 10),
                Text(isID ? 'Tambah / Edit Polygon' : 'Add / Edit Polygon'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 10),
                Text(isID ? 'Edit Plot' : 'Edit Plot'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'saprodi',
            child: Row(
              children: [
                Icon(Icons.grass_outlined, size: 18),
                SizedBox(width: 10),
                Text('Saprodi'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                const SizedBox(width: 10),
                Text(isID ? 'Hapus' : 'Delete',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () => c.goPolygon(ctx, item),
    );
    });
  }
}
