import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/screens/widgets/coordinate_capture.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class KthAddPlotController extends GetxController {
  KthAddPlotController({required this.farmerId, this.farmerName, this.initialPolygonWkt});

  final int farmerId;
  final String? farmerName;

  /// Prefilled polygon WKT — used when returning from a resumed polygon capture.
  final String? initialPolygonWkt;

  final nameCtrl = TextEditingController();
  final landAreaCtrl = TextEditingController();
  final plantsCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();
  final polygonCtrl = TextEditingController();

  final isSaving = false.obs;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    final wkt = initialPolygonWkt?.trim();
    if (wkt != null && wkt.isNotEmpty) polygonCtrl.text = wkt;
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    landAreaCtrl.dispose();
    plantsCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    polygonCtrl.dispose();
    super.onClose();
  }

  double? _parseDouble(String s) {
    final x = s.trim().replaceAll(',', '.');
    return double.tryParse(x);
  }

  int? _parseInt(String s) => int.tryParse(s.trim());

  bool _coordInRange(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0.0 && lng == 0.0);
  }

  /// Validasi ringan polygon WKT (opsional)
  bool _looksLikeWktPolygon(String s) {
    final t = s.trim().toUpperCase();
    if (t.isEmpty) return true; // boleh kosong
    return t.startsWith('POLYGON((') && t.endsWith('))');
  }

  void _resetForm() {
    nameCtrl.clear();
    landAreaCtrl.clear();
    plantsCtrl.clear();
    latCtrl.clear();
    lngCtrl.clear();
    polygonCtrl.clear();
    formKey.currentState?.reset();
  }

  Future<void> save(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final plotName = nameCtrl.text.trim();
    final landArea = landAreaCtrl.text.trim(); // string, biar presisi tetap
    final plants = _parseInt(plantsCtrl.text) ?? 0;

    final lat = _parseDouble(latCtrl.text);
    final lng = _parseDouble(lngCtrl.text);

    final isID = LanguageService.to.isId;
    if (lat == null || lng == null || !_coordInRange(lat, lng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isID ? 'Koordinat tidak valid' : 'Invalid coordinates')),
      );
      return;
    }

    final polygonWkt =
        polygonCtrl.text.trim().isEmpty ? null : polygonCtrl.text.trim();
    if (polygonWkt != null && !_looksLikeWktPolygon(polygonWkt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isID
                ? 'Format polygon tidak valid. Contoh: POLYGON((lng lat, lng lat, ...))'
                : 'Invalid polygon format. Example: POLYGON((lng lat, lng lat, ...))',
          ),
        ),
      );
      return;
    }

    isSaving.value = true;
    try {
      final api = PlotApi();

      final res = await api.addPlotOfflineFirst(
        plotName: plotName,
        landArea: landArea,
        numberOfPlants: plants,
        latitude: lat,
        longitude: lng,
        farmerId: farmerId,
        polygon: polygonWkt,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(res.message))),
      );

      _resetForm();
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> getCoordinates(BuildContext context) async {
    await captureCoordinatesInto(context, latCtrl: latCtrl, lngCtrl: lngCtrl);
  }

  Future<void> goPolygonEditor(BuildContext context) async {
    final ok = await Navigator.pushNamed(
      context,
      '/kth_polygon',
      arguments: {
        'draft': true,
        'polygonWkt': polygonCtrl.text.trim(),
        'farmerId': farmerId,
        'farmerName': farmerName,
      },
    );

    if (ok is String) {
      polygonCtrl.text = ok;
    }
  }
}
