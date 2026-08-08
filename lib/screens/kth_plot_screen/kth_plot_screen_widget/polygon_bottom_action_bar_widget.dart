import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';

class PolygonBottomActionBar extends StatelessWidget {
  final KthPolygonController c;
  final BuildContext ctx;

  const PolygonBottomActionBar({
    super.key,
    required this.c,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final canUndo = c.points.isNotEmpty;
      final canClear = c.points.isNotEmpty;
      final canSave = c.points.length >= 3;
      final loading = c.isLoading.value;

      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : () => c.addPoint(ctx),
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: Text(isID ? 'Tambah Point' : 'Add Point'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeColor.darkestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (canUndo && !loading) ? c.undo : null,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThemeColor.darkestGreen,
                    side: BorderSide(
                        color: ThemeColor
                            .darkestGreen
                            .withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (canClear && !loading) ? c.clear : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(
                        color: Colors.red.shade700
                            .withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      (canSave && !loading) ? () => c.save(ctx) : null,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(isID ? 'Simpan' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeColor.darkestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
