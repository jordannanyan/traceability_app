import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/tree_screen/tree_upsert_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeUpsertScreen extends StatelessWidget {
  /// null = add; non-null = edit
  final int? treeId;

  /// Optional context filters
  final int? kthId;
  final int? farmerId;

  /// If provided, plot & farmer are locked (cannot be changed)
  final int? plotId;

  const TreeUpsertScreen({
    super.key,
    this.treeId,
    this.kthId,
    this.farmerId,
    this.plotId,
  });

  @override
  Widget build(BuildContext context) {
    final tag =
        'upsert_${treeId ?? 0}_${plotId ?? 0}_${farmerId ?? 0}_${kthId ?? 0}';

    final c = Get.put(
      TreeUpsertController(
        treeId: treeId,
        kthId: kthId,
        farmerId: farmerId,
        plotId: plotId,
      ),
      tag: tag,
    );

    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final loading = c.loading.value;
      final prefilling = c.prefilling.value;
      final loadingPlots = c.loadingPlots.value;
      final editing = treeId != null;
      final selectedPlot = c.selectedPlot.value;
      final plots = c.plots.toList();
      final lockPlot = c.lockPlotAndFarmer;
      final selectedSpecies = c.selectedSpecies.value;
      final plantedAt = c.plantedAt.value;
      final localImagePath = c.localImagePath.value;
      final networkPhotoUrl = c.networkPhotoUrl.value;
      final lat = c.lat.value;
      final lng = c.lng.value;
      final gpsTimestamp = c.gpsTimestamp.value;
      final gpsAccuracy = c.gpsAccuracy.value;
      final gpsSampleCount = c.gpsSampleCount.value;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            editing
                ? (isID ? 'Ubah Pohon' : 'Edit Tree')
                : (isID ? 'Tambah Pohon' : 'Add Tree'),
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
          actions: [
            IconButton(
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              onPressed: loading ? null : () => c.save(context),
            ),
          ],
        ),
        body: prefilling
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : AbsorbPointer(
                absorbing: loading,
                child: Form(
                  key: c.form,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        18, 18, 18, 18 + MediaQuery.viewPaddingOf(context).bottom),
                    children: [
                      // ====== 1) PLOT & FARMER ======
                      Container(
                        padding: const EdgeInsets.all(Insets.lg),
                        decoration: _cardDeco(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lockPlot) ...[
                              Text(
                                isID ? 'Lahan' : 'Plot',
                                style:
                                    ThemeTextStyle.textStyleFirstBold,
                              ),
                              const SizedBox(height: 6),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  selectedPlot?.code ?? '-',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isID ? 'Nama Petani' : 'Farmer Name',
                                style:
                                    ThemeTextStyle.textStyleFirstBold,
                              ),
                              const SizedBox(height: 6),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                    selectedPlot?.farmerLabel ?? '-'),
                              ),
                            ] else ...[
                              DropdownButtonFormField<PlotOption>(
                                value: selectedPlot,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: loadingPlots
                                      ? (isID ? 'Memuat lahan…' : 'Loading plots…')
                                      : (isID ? 'Pilih Kode Lahan' : 'Select Plot Code'),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: loadingPlots
                                      ? const Padding(
                                          padding: EdgeInsets.all(Insets.md),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                items: plots.map((opt) {
                                  return DropdownMenuItem<PlotOption>(
                                    value: opt,
                                    child: Text(
                                        '${opt.code} — ${opt.farmerLabel}'),
                                  );
                                }).toList(),
                                onChanged: loadingPlots
                                    ? null
                                    : (val) =>
                                        c.selectedPlot.value = val,
                              ),
                              const SizedBox(height: 12),
                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: isID ? 'Nama Petani' : 'Farmer Name',
                                  border: const OutlineInputBorder(),
                                ),
                                child: Text(
                                    selectedPlot?.farmerName ?? ''),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ====== 2) FOTO POHON ======
                      Container(
                        padding: const EdgeInsets.all(Insets.lg),
                        decoration: _cardDeco(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isID ? 'Foto Pohon' : 'Tree Photo',
                              style: ThemeTextStyle.textStyleFirstBold,
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () => c.pickImage(context),
                              borderRadius: BorderRadius.circular(Radii.md),
                              child: Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.green
                                      .withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(Radii.md),
                                ),
                                child: _photoWidget(
                                    localImagePath, networkPhotoUrl),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isID
                                  ? 'Ketuk untuk mengambil foto. Koordinat GPS akan diambil otomatis saat memotret.'
                                  : 'Tap to take a photo. GPS coordinates will be captured automatically.',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ====== 3) DATA POHON ======
                      Container(
                        padding: const EdgeInsets.all(Insets.lg),
                        decoration: _cardDeco(),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedSpecies,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isID ? 'Jenis/Spesies' : 'Type / Species',
                                border: const OutlineInputBorder(),
                              ),
                              items: TreeUpsertController.speciesOptions
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  c.selectedSpecies.value = v,
                              validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? (isID ? 'Wajib dipilih' : 'Required')
                                      : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ====== 4) TANGGAL TANAM ======
                      Container(
                        padding: const EdgeInsets.all(Insets.lg),
                        decoration: _cardDeco(),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(isID ? 'Tanggal Tanam' : 'Planting Date'),
                          subtitle: Text(
                            '${plantedAt.day.toString().padLeft(2, '0')}-'
                            '${plantedAt.month.toString().padLeft(2, '0')}-'
                            '${plantedAt.year}',
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () => c.pickDate(context),
                            icon: const Icon(Icons.date_range),
                            label: Text(isID ? 'Pilih' : 'Select'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ====== 5) KOORDINAT GPS ======
                      Container(
                        padding: const EdgeInsets.all(Insets.lg),
                        decoration: _cardDeco(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isID ? 'Koordinat GPS' : 'GPS Coordinates',
                              style: ThemeTextStyle.textStyleFirstBold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (lat != null && lng != null)
                                  ? 'Lat: ${lat.toStringAsFixed(6)}\n'
                                      'Lng: ${lng.toStringAsFixed(6)}'
                                      '${gpsAccuracy != null ? (isID ? '\nAkurasi: ±${gpsAccuracy.toStringAsFixed(1)} m' : '\nAccuracy: ±${gpsAccuracy.toStringAsFixed(1)} m') : ''}'
                                      '${gpsSampleCount > 0 ? (isID ? ' ($gpsSampleCount sampel)' : ' ($gpsSampleCount samples)') : ''}'
                                      '${gpsTimestamp != null ? (isID ? '\n(terambil otomatis)' : '\n(captured automatically)') : ''}'
                                  : (isID
                                      ? 'Koordinat belum tersedia.\nAmbil foto untuk menangkap lokasi otomatis.'
                                      : 'Coordinates not available yet.\nTake a photo to capture location automatically.'),
                              style: TextStyle(
                                color: (gpsAccuracy != null &&
                                        gpsAccuracy > 10)
                                    ? Colors.orange.shade900
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: loading
                                  ? null
                                  : () => c.save(context),
                              icon: loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(isID ? 'Simpan' : 'Save'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: loading
                                  ? null
                                  : () =>
                                      c.save(context, addAnother: true),
                              icon: const Icon(
                                  Icons.add_circle_outline),
                              label: Text(
                                  isID ? 'Simpan & Tambah Lagi' : 'Save & Add Another'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      );
    });
  }

  Widget _photoWidget(String? localPath, String? networkUrl) {
    if (localPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          // Downsample saat decode supaya tidak memuat bitmap full-res
          // (hingga 1920px) hanya untuk pratinjau setinggi 180px → cegah OOM.
          cacheWidth: 1080,
        ),
      );
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Image.network(
          networkUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image, size: 48)),
        ),
      );
    }
    return const Center(child: Icon(Icons.camera_alt, size: 48));
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
