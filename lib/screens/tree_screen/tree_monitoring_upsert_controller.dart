import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:traceability_app/models/api/tree_monitoring_api.dart';
import 'package:traceability_app/screens/widgets/gps_loading_dialog.dart';
import 'package:traceability_app/screens/widgets/in_app_camera_screen.dart';
import 'package:traceability_app/services/gps_sampler.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class TreeMonitoringUpsertController extends GetxController {
  final int treeId;
  TreeMonitoringUpsertController({required this.treeId});

  final form = GlobalKey<FormState>();

  final measuredAt = DateTime.now().obs;
  final health = 'Sehat'.obs;
  final localImagePath = RxnString();
  final lat = Rxn<double>();
  final lng = Rxn<double>();
  final acc = Rxn<double>();
  final saving = false.obs;

  final circumC = TextEditingController();
  final healthDescC = TextEditingController();

  static const healthOptions = ['Sehat', 'Tidak Sehat', 'Mati'];

  @override
  void onClose() {
    circumC.dispose();
    healthDescC.dispose();
    super.onClose();
  }

  Future<void> pickImage(BuildContext context) async {
    // Serialize the location permission prompt before launching the camera
    // (Android refuses overlapping permission requests with empty grantResults).
    await ensureLocationPermission();

    // Sampling GPS jalan paralel dengan kamera; dialog progress dibuka
    // setelah foto selesai diambil. Sama persis dengan flow input pohon.
    final session = startGpsSampling();

    if (!context.mounted) {
      session.cancel();
      return;
    }

    // In-app camera so Android does not kill our process for memory while it
    // is open — the parallel GPS session and the accuracy dialog survive.
    final path = await captureInAppPhoto(context,
        title: LanguageService.to.isId ? 'Foto Monitoring' : 'Monitoring Photo');
    if (path == null) {
      session.cancel();
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/monitor_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final fileName = 'monitor_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${photosDir.path}/$fileName');
    await File(path).copy(dest.path);

    localImagePath.value = dest.path;

    if (!context.mounted) {
      session.cancel();
      return;
    }

    final result = await showGpsLoadingDialog(context, session: session);
    final pos = result.position;

    if (pos != null) {
      lat.value = pos.latitude;
      lng.value = pos.longitude;
      acc.value = pos.accuracy;
    } else {
      lat.value = null;
      lng.value = null;
      acc.value = null;
    }

    final msg = gpsResultMessage(result);
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
      initialDate: measuredAt.value,
    );
    if (d == null) return;

    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(measuredAt.value),
    );
    measuredAt.value = DateTime(
      d.year,
      d.month,
      d.day,
      t?.hour ?? measuredAt.value.hour,
      t?.minute ?? measuredAt.value.minute,
    );
  }

  double? _toDouble(String s) {
    final cleaned = s.trim().replaceAll(',', '.');
    final d = double.tryParse(cleaned);
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  String fmtDateTime(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> save(BuildContext context) async {
    if (saving.value) return;
    if (!form.currentState!.validate()) return;

    final circum =
        circumC.text.trim().isEmpty ? null : _toDouble(circumC.text);
    if (circum != null && circum < 0) {
      final isID = LanguageService.to.isId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isID
                ? 'Keliling tidak boleh negatif'
                : 'Circumference cannot be negative')),
      );
      return;
    }

    saving.value = true;
    final api = TreeMonitoringApi();

    try {
      final res = await api.addMonitoringOfflineFirst(
        treeId: treeId,
        measuredAt: measuredAt.value,
        circumferenceCm: circum,
        healthStatus: health.value,
        healthDesc: '-',
        latitude: lat.value,
        longitude: lng.value,
        accuracyM: acc.value,
        photoPath: localImagePath.value,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(res.message))));
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      final isID = LanguageService.to.isId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isID
                ? 'Gagal menyimpan monitoring: $e'
                : 'Failed to save monitoring: $e')),
      );
    } finally {
      saving.value = false;
    }
  }

  /// Expose [FilteringTextInputFormatter] for use in the screen
  static InputFormatter get circumFormatter =>
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'));
}

// Re-export for convenience
typedef InputFormatter = TextInputFormatter;
