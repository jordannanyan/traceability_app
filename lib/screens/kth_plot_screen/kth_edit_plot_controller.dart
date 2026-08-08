import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart'
    as plot_list;
import 'package:traceability_app/screens/widgets/coordinate_capture.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class KthEditPlotController extends GetxController {
  final nameCtrl = TextEditingController();
  final landAreaCtrl = TextEditingController();
  final plantsCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();
  final polygonCtrl = TextEditingController();

  final isSaving = false.obs;

  int? plotId;
  int? farmerId;
  String? farmerName;
  plot_list.Datum? plot;

  bool _initialized = false;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

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

  /// Populates controllers from route arguments. Safe to call on every
  /// build() — the [_initialized] guard prevents double-initialisation.
  void initFromArgs(dynamic args) {
    if (_initialized) return;

    plot_list.Datum? d;

    if (args is plot_list.Datum) {
      d = args;
    } else if (args is Map) {
      final m = Map<String, dynamic>.from(args);

      // kasus: Map berisi 'plot': Datum
      final p = m['plot'];
      if (p is plot_list.Datum) {
        d = p;
      }

      // simpan farmer info dari Map
      farmerId = _toInt(m['farmerId'] ?? m['farmer_id']) ?? farmerId;
      farmerName = m['farmerName']?.toString() ?? farmerName;

      // fallback kalau Map tidak berisi Datum
      if (d == null) {
        plotId = _toInt(m['id']);
        nameCtrl.text = (m['plotName'] ?? m['plot_name'] ?? '').toString();
        landAreaCtrl.text =
            (m['landArea'] ?? m['land_area'] ?? '').toString();
        plantsCtrl.text =
            (m['numberOfPlants'] ?? m['number_of_plants'] ?? 0).toString();
        latCtrl.text = (m['latitude'] ?? '').toString();
        lngCtrl.text = (m['longitude'] ?? '').toString();
        polygonCtrl.text =
            (m['polygonWkt'] ?? m['polygon'] ?? '').toString();

        _initialized = true;
        return;
      }
    }

    if (d != null) {
      plot = d;
      plotId = d.id;
      farmerId = farmerId ?? d.farmerId; // pakai yang dari Map dulu kalau ada

      nameCtrl.text = (d.plotName ?? '').toString();
      landAreaCtrl.text = (d.landArea ?? '').toString();
      plantsCtrl.text = (d.numberOfPlants ?? 0).toString();
      latCtrl.text = (d.latitude ?? '').toString();
      lngCtrl.text = (d.longitude ?? '').toString();
      polygonCtrl.text = (d.polygonWkt ?? '').toString();
    }

    _initialized = true;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
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

  bool _looksLikeWktPolygon(String s) {
    final t = s.trim().toUpperCase();
    if (t.isEmpty) return true;
    return t.startsWith('POLYGON((') && t.endsWith('))');
  }

  Future<void> save(BuildContext context) async {
    final isID = LanguageService.to.isId;
    if (plotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isID ? 'Plot ID tidak ditemukan' : 'Plot ID not found')),
      );
      return;
    }

    if (!formKey.currentState!.validate()) return;

    final plotName = nameCtrl.text.trim();
    final landArea = landAreaCtrl.text.trim(); // string untuk presisi
    final plants = _parseInt(plantsCtrl.text) ?? 0;

    final lat = _parseDouble(latCtrl.text);
    final lng = _parseDouble(lngCtrl.text);

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
      // farmer_id: kalau tidak ada di args, ambil dari prefs (fallback)
      int resolvedFarmerId = farmerId ?? 0;
      if (resolvedFarmerId == 0) {
        final prefs = await SharedPreferences.getInstance();
        resolvedFarmerId = prefs.getInt('id') ?? 0;
      }
      if (resolvedFarmerId == 0) {
        throw Exception(
            isID ? 'Farmer ID tidak ditemukan.' : 'Farmer ID not found.');
      }

      final api = PlotApi();
      final res = await api.editPlotOfflineFirst(
        id: plotId!,
        plotName: plotName,
        landArea: landArea,
        numberOfPlants: plants,
        latitude: lat,
        longitude: lng,
        farmerId: resolvedFarmerId,
        polygon: polygonWkt,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(res.message))),
      );

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
    final result = await Navigator.pushNamed(
      context,
      '/kth_polygon',
      arguments: {
        'draft': false,
        'plot': plot,
        'plotId': plotId,
        'polygonWkt': polygonCtrl.text.trim(),
        'farmerId': farmerId,
        'farmerName': farmerName,
      },
    );

    if (result is String) {
      polygonCtrl.text = result;
    }
  }
}
