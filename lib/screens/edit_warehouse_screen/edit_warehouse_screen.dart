import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/screens/edit_warehouse_screen/edit_warehouse_controller.dart';
import 'package:traceability_app/screens/edit_warehouse_screen/edit_warehouse_screen_widget/edit_warehouse_form_card_widget.dart';
import 'package:traceability_app/screens/edit_warehouse_screen/edit_warehouse_screen_widget/edit_warehouse_header_widget.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class EditWarehouseScreen extends StatelessWidget {
  const EditWarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments as wh.Datum?;
    final c = Get.put(
      EditWarehouseController(item: item),
      tag: '${item?.id}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final isID = c.language.value == 'id';
          final name = item?.warehouseName;
          return Text(
            (name != null && name.isNotEmpty)
                ? 'Edit $name'
                : (isID ? 'Edit Gudang' : 'Edit Warehouse'),
          );
        }),
      ),
      body: Obx(() {
        final isID = c.language.value == 'id';
        final isSaving = c.isSaving.value;
        final isOfflineView = c.isOfflineView.value;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            EditWarehouseHeader(
              title: isID ? 'Edit Gudang' : 'Edit Warehouse',
              subtitle: isID
                  ? 'Perbarui data gudang'
                  : 'Update warehouse details',
              chipLabel: item?.warehouseName ?? '-',
            ),

            if (isOfflineView) ...[
              const SizedBox(height: 12),
              _OfflineBanner(isID: isID),
            ],

            const SizedBox(height: 16),
            EditWarehouseFormCard(
              formKey: c.formKey,
              nameCtrl: c.nameCtrl,
              addressCtrl: c.addressCtrl,
              isID: isID,
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isSaving ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    label: Text(isID ? 'Batal' : 'Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : () => c.save(context),
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isSaving
                          ? (isID ? 'Menyimpan...' : 'Saving...')
                          : (isID ? 'Simpan Perubahan' : 'Save Changes'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ThemeColor.darkestGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen-specific small widget
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final bool isID;

  const _OfflineBanner({required this.isID});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5CC),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isID
                  ? 'Mode offline: perubahan akan disimpan dan disinkronkan saat online.'
                  : 'Offline mode: changes will be queued and synced when online.',
            ),
          ),
        ],
      ),
    );
  }
}
