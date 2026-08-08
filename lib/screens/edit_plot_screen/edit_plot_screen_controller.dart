import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as farmer_list;
import 'package:traceability_app/screens/widgets/coordinate_capture.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class EditPlotController extends GetxController {
  final farmer_list.Datum? plot;
  EditPlotController({this.plot});

  final formKey = GlobalKey<FormState>();

  final nameC = TextEditingController();
  final landAreaC = TextEditingController();
  final plantsC = TextEditingController();
  final latC = TextEditingController();
  final lngC = TextEditingController();

  final saving = false.obs;
  final headerName = ''.obs;

  int? plotId;

  @override
  void onInit() {
    super.onInit();
    if (plot != null) {
      plotId = plot!.id;
      nameC.text = plot!.plotName ?? '';
      landAreaC.text = (plot!.landArea ?? '').toString();
      plantsC.text = (plot!.numberOfPlants ?? 0).toString();
      latC.text = (plot!.latitude ?? '').toString();
      lngC.text = (plot!.longitude ?? '').toString();
      headerName.value = plot!.plotName ?? '';
    }
    nameC.addListener(() => headerName.value = nameC.text);
  }

  @override
  void onClose() {
    nameC.dispose();
    landAreaC.dispose();
    plantsC.dispose();
    latC.dispose();
    lngC.dispose();
    super.onClose();
  }

  double? parseDouble(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  int? parseInt(String s) => int.tryParse(s.trim());

  bool coordInRange(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0.0 && lng == 0.0);

  Future<void> getCoordinates(BuildContext context) async {
    await captureCoordinatesInto(context, latCtrl: latC, lngCtrl: lngC);
  }

  Future<void> save(BuildContext context) async {
    final isID = LanguageService.to.isId;
    if (plotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isID ? 'Plot ID tidak ditemukan' : 'Plot ID not found')));
      return;
    }
    if (!formKey.currentState!.validate()) return;

    final name = nameC.text.trim();
    final area = landAreaC.text.trim();
    final plants = parseInt(plantsC.text) ?? 0;
    final lat = parseDouble(latC.text);
    final lng = parseDouble(lngC.text);

    if (lat == null || lng == null || !coordInRange(lat, lng)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isID ? 'Koordinat tidak valid' : 'Invalid coordinates')));
      return;
    }

    saving.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('id') ?? 0;
      if (farmerId == 0) {
        throw Exception(isID
            ? 'Farmer ID tidak ditemukan. Silakan login ulang.'
            : 'Farmer ID not found. Please log in again.');
      }

      final res = await PlotApi().editPlotOfflineFirst(
        id: plotId!,
        plotName: name,
        landArea: area,
        numberOfPlants: plants,
        latitude: lat,
        longitude: lng,
        farmerId: farmerId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(res.message))));
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      saving.value = false;
    }
  }
}
