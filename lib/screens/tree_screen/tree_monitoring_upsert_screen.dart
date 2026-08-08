import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/tree_screen/tree_monitoring_upsert_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeMonitoringUpsertScreen extends StatelessWidget {
  final int treeId;
  const TreeMonitoringUpsertScreen({
    super.key,
    required this.treeId,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      TreeMonitoringUpsertController(treeId: treeId),
      tag: 'mon_upsert_$treeId',
    );

    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final saving = c.saving.value;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            isID ? 'Tambah Monitoring' : 'Add Monitoring',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
          actions: [
            IconButton(
              icon: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              onPressed: saving ? null : () => c.save(context),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: saving,
          child: Form(
            key: c.form,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  18, 18, 18, 18 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                // 1) TANGGAL & WAKTU
                Obx(() => Container(
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: _cardDeco(),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(isID ? 'Waktu Pengukuran *' : 'Measurement Time *'),
                        subtitle:
                            Text(c.fmtDateTime(c.measuredAt.value)),
                        trailing: ElevatedButton.icon(
                          onPressed: () =>
                              c.pickDateTime(context),
                          icon: const Icon(Icons.date_range),
                          label: Text(isID ? 'Pilih' : 'Select'),
                        ),
                      ),
                    )),

                const SizedBox(height: 16),

                // 2) DATA MONITORING
                Obx(() => Container(
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: _cardDeco(),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: c.health.value,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: isID ? 'Kesehatan *' : 'Health *',
                              border: const OutlineInputBorder(),
                            ),
                            items: TreeMonitoringUpsertController
                                .healthOptions
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(_healthLabel(s, isID))))
                                .toList(),
                            onChanged: (v) =>
                                c.health.value = v ?? 'Sehat',
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? (isID ? 'Wajib diisi' : 'Required')
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: c.circumC,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              TreeMonitoringUpsertController
                                  .circumFormatter,
                            ],
                            decoration: InputDecoration(
                              labelText: isID
                                  ? 'Keliling Pohon (cm)'
                                  : 'Tree Circumference (cm)',
                              hintText: isID ? 'contoh: 25.5' : 'e.g. 25.5',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 16),

                // 3) FOTO
                Obx(() => Container(
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: _cardDeco(),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            isID ? 'Foto Monitoring' : 'Monitoring Photo',
                            style:
                                ThemeTextStyle.textStyleFirstBold,
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => c.pickImage(context),
                            borderRadius:
                                BorderRadius.circular(Radii.md),
                            child: Container(
                              width: double.infinity,
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.green
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(Radii.md),
                              ),
                              child: c.localImagePath.value == null
                                  ? const Center(
                                      child: Icon(
                                          Icons.camera_alt,
                                          size: 48))
                                  : ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              12),
                                      child: Image.file(
                                        File(c.localImagePath
                                            .value!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isID
                                ? 'Ketuk untuk mengambil foto. Koordinat GPS akan diambil otomatis saat memotret.'
                                : 'Tap to take a photo. GPS coordinates will be captured automatically.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 16),

                // 4) KOORDINAT GPS
                Obx(() => Container(
                      padding: const EdgeInsets.all(Insets.lg),
                      decoration: _cardDeco(),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            isID ? 'Koordinat GPS' : 'GPS Coordinates',
                            style:
                                ThemeTextStyle.textStyleFirstBold,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (c.lat.value != null &&
                                    c.lng.value != null)
                                ? 'Lat: ${c.lat.value!.toStringAsFixed(6)}\nLng: ${c.lng.value!.toStringAsFixed(6)}'
                                : (isID
                                    ? 'Koordinat belum tersedia.\nAmbil foto untuk menangkap lokasi otomatis.'
                                    : 'Coordinates not available yet.\nTake a photo to capture location automatically.'),
                            style: const TextStyle(
                                color: Colors.black87),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 24),

                // SAVE
                Obx(() => SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: c.saving.value
                            ? null
                            : () => c.save(context),
                        icon: c.saving.value
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(isID ? 'Simpan' : 'Save'),
                      ),
                    )),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _healthLabel(String value, bool isID) {
    if (isID) return value;
    switch (value) {
      case 'Sehat':
        return 'Healthy';
      case 'Tidak Sehat':
        return 'Unhealthy';
      case 'Mati':
        return 'Dead';
      default:
        return value;
    }
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.10),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );
}
