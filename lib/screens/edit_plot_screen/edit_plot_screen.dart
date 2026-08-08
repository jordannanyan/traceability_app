import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as farmer_list;
import 'package:traceability_app/screens/edit_plot_screen/edit_plot_screen_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class EditPlotScreen extends StatelessWidget {
  const EditPlotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final plot = args is farmer_list.Datum ? args : null;

    final c = Get.put(EditPlotController(plot: plot));

    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final saving = c.saving.value;
      final headerName = c.headerName.value;

      return Scaffold(
        appBar: AppBar(
          title: Text(isID ? 'Edit Plot' : 'Edit Plot'),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            _Header(
              title: isID ? 'Edit Plot' : 'Edit Plot',
              subtitle: isID ? 'Perbarui data lahan kamu' : 'Update your plot data',
              chipLabel: headerName.isEmpty
                  ? (isID ? 'Edit Plot' : 'Edit Plot')
                  : headerName,
            ),
            const SizedBox(height: 16),
            _formCard(context, c, saving, isID),
          ],
        ),
      );
    });
  }

  Widget _formCard(
      BuildContext context, EditPlotController c, bool saving, bool isID) {
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
        key: c.formKey,
        child: Column(
          children: [
            _field(
              label: isID ? 'Nama Plot' : 'Plot Name',
              controller: c.nameC,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isID ? 'Wajib diisi' : 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            _field(
              label: isID ? 'Luas Lahan (Ha)' : 'Land Area (Ha)',
              controller: c.landAreaC,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              textInputAction: TextInputAction.next,
              hintText: isID ? 'contoh: 1.00' : 'e.g. 1.00',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isID ? 'Wajib diisi' : 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            _field(
              label: isID ? 'Jumlah Tanaman' : 'Number of Plants',
              controller: c.plantsC,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || c.parseInt(v.trim()) == null)
                  ? (isID ? 'Angka tidak valid' : 'Invalid number')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    label: 'Latitude',
                    controller: c.latC,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) => c.parseDouble(v ?? '') == null
                        ? (isID ? 'Tidak valid' : 'Invalid')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    label: 'Longitude',
                    controller: c.lngC,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                    textInputAction: TextInputAction.done,
                    validator: (v) => c.parseDouble(v ?? '') == null
                        ? (isID ? 'Tidak valid' : 'Invalid')
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: saving ? null : () => c.getCoordinates(context),
                icon: const Icon(Icons.my_location),
                label: Text(isID ? 'Ambil Koordinat' : 'Get Coordinates'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(isID ? 'Batal' : 'Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThemeColor.darkestGreen,
                      side: BorderSide(
                          color: ThemeColor
                              .darkestGreen
                              .withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving ? null : () => c.save(context),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      saving
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
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ThemeTextStyle.textStyleForthBold),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ThemeColor.darkestGreen),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final String chipLabel;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.chipLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
          colors: [
            ThemeColor.darkestGreen.withValues(alpha: 0.10),
            Colors.white
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border:
            Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.map_outlined,
                color: ThemeColor.darkestGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ThemeTextStyle.textStyleForthBold.copyWith(
                        fontSize: 20,
                        color: ThemeColor.darkestGreen,
                      ),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.xl),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.agriculture,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        chipLabel.isEmpty ? '-' : chipLabel,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
