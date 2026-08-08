import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_form_field_widget.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PlotFormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController landAreaCtrl;
  final TextEditingController plantsCtrl;
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;
  final TextEditingController polygonCtrl;
  final RxBool isSaving;
  final String saveLabel;
  final String polygonButtonLabel;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenPolygonEditor;
  final VoidCallback? onGetCoordinates;

  const PlotFormCard({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.landAreaCtrl,
    required this.plantsCtrl,
    required this.latCtrl,
    required this.lngCtrl,
    required this.polygonCtrl,
    required this.isSaving,
    required this.saveLabel,
    required this.polygonButtonLabel,
    this.onSave,
    this.onCancel,
    this.onOpenPolygonEditor,
    this.onGetCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            PlotFormField(
              label: isID ? 'Nama Plot' : 'Plot Name',
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isID ? 'Wajib diisi' : 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            PlotFormField(
              label: isID ? 'Luas Lahan (Ha)' : 'Land Area (Ha)',
              controller: landAreaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              hintText: isID ? 'contoh: 1.00' : 'e.g. 1.00',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isID ? 'Wajib diisi' : 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            PlotFormField(
              label: isID ? 'Jumlah Tanaman' : 'Number of Plants',
              controller: plantsCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || int.tryParse(v.trim()) == null)
                  ? (isID ? 'Angka tidak valid' : 'Invalid number')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PlotFormField(
                    label: 'Latitude',
                    controller: latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final x = (v ?? '').trim().replaceAll(',', '.');
                      return double.tryParse(x) == null
                          ? (isID ? 'Tidak valid' : 'Invalid')
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PlotFormField(
                    label: 'Longitude',
                    controller: lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final x = (v ?? '').trim().replaceAll(',', '.');
                      return double.tryParse(x) == null
                          ? (isID ? 'Tidak valid' : 'Invalid')
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Obx(
                () => TextButton.icon(
                  onPressed:
                      isSaving.value ? null : onGetCoordinates,
                  icon: const Icon(Icons.my_location),
                  label: Text(isID ? 'Ambil Koordinat' : 'Get Coordinates'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PlotFormField(
              label: isID ? 'Polygon (WKT) - Opsional' : 'Polygon (WKT) - Optional',
              controller: polygonCtrl,
              textInputAction: TextInputAction.done,
              hintText: 'POLYGON((lng lat, lng lat, ...))',
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final t = s.toUpperCase();
                return (t.startsWith('POLYGON((') && t.endsWith('))'))
                    ? null
                    : (isID ? 'Format WKT tidak valid' : 'Invalid WKT format');
              },
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Obx(
                () => TextButton.icon(
                  onPressed: isSaving.value ? null : onOpenPolygonEditor,
                  icon: const Icon(Icons.polyline),
                  label: Text(polygonButtonLabel),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSaving.value ? null : onCancel,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(isID ? 'Batal' : 'Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeColor.darkestGreen,
                        side: BorderSide(
                          color: ThemeColor
                              .darkestGreen
                              .withValues(alpha: 0.4),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSaving.value ? null : onSave,
                      icon: isSaving.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        isSaving.value
                            ? (isID ? 'Menyimpan...' : 'Saving...')
                            : saveLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeColor.darkestGreen,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    });
  }
}
