import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/models/get_trees.dart' as tm;
import 'package:traceability_app/screens/widgets/gps_loading_dialog.dart';
import 'package:traceability_app/screens/widgets/in_app_camera_screen.dart';
import 'package:traceability_app/services/gps_sampler.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

// ====== PlotOption model (public) ======
class PlotOption {
  final int id;
  final String code;
  final String farmerName;
  final int? farmerId;

  const PlotOption({
    required this.id,
    required this.code,
    required this.farmerName,
    this.farmerId,
  });

  String get farmerLabel {
    final n = farmerName.trim();
    if (n.isNotEmpty) return n;
    if (farmerId != null && farmerId != 0) {
      final isID = LanguageService.to.isId;
      return isID ? 'Petani #$farmerId' : 'Farmer #$farmerId';
    }
    return '-';
  }

  factory PlotOption.fromAny(Map<String, dynamic> m) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    String toStr(dynamic v) => (v ?? '').toString();

    final id = toInt(m['id']);
    final codeRaw = toStr(
      m['plot_name'] ??
          m['plotName'] ??
          m['name'] ??
          m['code'] ??
          m['plotCode'] ??
          m['plot_code'],
    ).trim();

    int? farmerId;
    if (m.containsKey('farmer_id') || m.containsKey('farmerId')) {
      farmerId = toInt(m['farmer_id'] ?? m['farmerId']);
      if (farmerId == 0) farmerId = null;
    }

    String farmer = '';
    final directFarmer = toStr(m['farmer_name'] ?? m['farmerName']).trim();
    if (directFarmer.isNotEmpty) {
      farmer = directFarmer;
    } else if (m['farmer'] is Map) {
      final fm = Map<String, dynamic>.from(m['farmer'] as Map);
      farmerId ??= toInt(fm['id'] ?? fm['farmer_id'] ?? fm['farmerId']);
      if (farmerId == 0) farmerId = null;
      farmer = toStr(
        fm['farmer_name'] ?? fm['farmerName'] ?? fm['name'] ?? fm['full_name'],
      ).trim();
    }

    return PlotOption(
      id: id,
      code: codeRaw.isEmpty ? 'Plot #$id' : codeRaw,
      farmerName: farmer,
      farmerId: farmerId,
    );
  }
}

// ====== Controller ======
class TreeUpsertController extends GetxController {
  final int? treeId;
  final int? kthId;
  final int? farmerId;
  final int? plotId;

  TreeUpsertController({
    this.treeId,
    this.kthId,
    this.farmerId,
    this.plotId,
  });

  final _api = TreeApi();

  final form = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final speciesC = TextEditingController();

  static const speciesOptions = [
    'Kayu Manis / Cinnamon',
    'Petai / Stink Bean',
    'Durian / Durian',
    'Mangga / Mango',
    'Kopi / Coffee',
    'Kakao / Cacao',
    'Alpukat / Avocado',
    'Pisang / Banana',
  ];

  final selectedSpecies = Rxn<String>();
  final plantedAt = DateTime.now().obs;
  final localImagePath = RxnString();
  final networkPhotoUrl = RxnString();
  final loading = false.obs;
  final prefilling = false.obs;

  final plots = <PlotOption>[].obs;
  final selectedPlot = Rxn<PlotOption>();
  final loadingPlots = false.obs;

  final lat = Rxn<double>();
  final lng = Rxn<double>();
  final gpsTimestamp = Rxn<DateTime>();
  final gpsAccuracy = Rxn<double>();
  final gpsSampleCount = 0.obs;

  bool get lockPlotAndFarmer => treeId != null || plotId != null;

  /// Same formula the screen uses to tag this controller.
  String get _selfTag =>
      'upsert_${treeId ?? 0}_${plotId ?? 0}_${farmerId ?? 0}_${kthId ?? 0}';

  /// Remove this controller from Get's registry after the current frame so
  /// the next open always gets a fresh instance with empty fields.
  void _deleteSelf() {
    final tag = _selfTag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<TreeUpsertController>(tag: tag)) {
        Get.delete<TreeUpsertController>(tag: tag, force: true);
      }
    });
  }

  static const _kLastPlotIdKey = 'last_plot_id';
  static const _kLastPlotCodeKey = 'last_plot_code';
  static const _kLastPlotFarmerKey = 'last_plot_farmer';
  static const _kLastPlotFarmerIdKey = 'last_plot_farmer_id';

  // Marker keys read by SplashController to resume an add/edit-tree screen when
  // the Android activity was destroyed while the camera was open. Keep in sync
  // with SplashController.
  static const kPendingTreeCaptureKey = 'pending_tree_capture';
  static const kPtcTreeIdKey = 'ptc_tree_id';
  static const kPtcPlotIdKey = 'ptc_plot_id';
  static const kPtcFarmerIdKey = 'ptc_farmer_id';
  static const kPtcKthIdKey = 'ptc_kth_id';

  Future<void> _setPendingCaptureMarker() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kPendingTreeCaptureKey, true);
    Future<void> setOrRemove(String k, int? v) =>
        v != null ? p.setInt(k, v) : p.remove(k);
    await setOrRemove(kPtcTreeIdKey, treeId);
    await setOrRemove(kPtcPlotIdKey, plotId);
    await setOrRemove(kPtcFarmerIdKey, farmerId);
    await setOrRemove(kPtcKthIdKey, kthId);
  }

  Future<void> _clearPendingCaptureMarker() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(kPendingTreeCaptureKey);
  }

  @override
  void onInit() {
    super.onInit();
    TreeApi.startAutoSyncListener();
    nameC.text = '-';
    _loadPlots().then((_) {
      if (treeId != null) _prefill();
    });
    // Pulihkan foto yang sempat diambil tetapi hilang karena Android
    // menghancurkan activity saat kamera terbuka (low memory).
    _recoverLostImage();
  }

  @override
  void onClose() {
    nameC.dispose();
    speciesC.dispose();
    super.onClose();
  }

  Future<PlotOption?> _loadLastPlot() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt(_kLastPlotIdKey);
    if (id == null) return null;
    final code = p.getString(_kLastPlotCodeKey) ?? 'Plot #$id';
    final farmer = p.getString(_kLastPlotFarmerKey) ?? '';
    final fid = p.getInt(_kLastPlotFarmerIdKey);
    return PlotOption(id: id, code: code, farmerName: farmer, farmerId: fid);
  }

  Future<void> _saveLastPlot(PlotOption opt) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastPlotIdKey, opt.id);
    await p.setString(_kLastPlotCodeKey, opt.code);
    await p.setString(_kLastPlotFarmerKey, opt.farmerName);
    if (opt.farmerId != null) {
      await p.setInt(_kLastPlotFarmerIdKey, opt.farmerId!);
    } else {
      await p.remove(_kLastPlotFarmerIdKey);
    }
  }

  Future<void> _autoSelectPlotIfPossible() async {
    if (selectedPlot.value != null) return;

    if (farmerId != null) {
      final fid = farmerId!;
      final match =
          plots.where((e) => (e.farmerId ?? 0) == fid).toList();
      if (match.isNotEmpty) {
        selectedPlot.value = match.first;
        return;
      }
      if (plots.isEmpty) {
        final last = await _loadLastPlot();
        if (last != null && (last.farmerId ?? 0) == fid) {
          selectedPlot.value = last;
        }
      }
      return;
    }

    if (plots.length == 1) {
      selectedPlot.value = plots.first;
      return;
    }

    if (plots.isNotEmpty) {
      final last = await _loadLastPlot();
      if (last != null) {
        selectedPlot.value = plots.firstWhere(
          (e) => e.id == last.id,
          orElse: () => plots.first,
        );
        return;
      }
    }

    if (plots.isEmpty) {
      final last = await _loadLastPlot();
      if (last != null) selectedPlot.value = last;
    }
  }

  Future<void> _loadPlots() async {
    loadingPlots.value = true;
    plots.clear();
    selectedPlot.value = null;

    try {
      if (plotId != null) {
        final m = await _api.getPlotByIdCached(plotId!);
        if (m != null) {
          final single = PlotOption.fromAny(m);
          plots.value = [single];
          selectedPlot.value = single;
          await _autoSelectPlotIfPossible();
          return;
        }

        final isID = LanguageService.to.isId;
        final stub = PlotOption(
          id: plotId!,
          code: 'Plot #$plotId',
          farmerName: farmerId != null
              ? (isID ? 'Petani #$farmerId' : 'Farmer #$farmerId')
              : '',
          farmerId: farmerId,
        );
        Get.snackbar(
          'Info',
          isID
              ? 'Plot #$plotId belum ada di cache. Menggunakan data sementara (stub).'
              : 'Plot #$plotId is not cached yet. Using temporary data (stub).',
          snackPosition: SnackPosition.BOTTOM,
        );
        plots.value = [stub];
        selectedPlot.value = stub;
        return;
      }

      if (farmerId != null) {
        final list = await _api.getPlotsByFarmerIdCached(farmerId!);
        plots.value =
            list.map<PlotOption>((e) => PlotOption.fromAny(e)).toList();
        await _autoSelectPlotIfPossible();
        return;
      }

      if (kthId != null) {
        final list =
            await _api.getPlotsByKthIdCached(kthId!, perPage: 400);
        plots.value =
            list.map<PlotOption>((e) => PlotOption.fromAny(e)).toList();
        await _autoSelectPlotIfPossible();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final kid = prefs.getInt('id');
      List<Map<String, dynamic>> rows;
      if (kid != null && kid != 0) {
        rows = await _api.getPlotsByKthIdCached(kid, perPage: 400);
      } else {
        rows = await _api.getAllPlotsCached(page: 1, perPage: 400);
      }
      plots.value =
          rows.map<PlotOption>((e) => PlotOption.fromAny(e)).toList();
      await _autoSelectPlotIfPossible();
    } catch (e) {
      final isID = LanguageService.to.isId;
      Get.snackbar(
        'Error',
        isID
            ? 'Gagal memuat data lahan (offline-first): $e'
            : 'Failed to load plot data (offline-first): $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _autoSelectPlotIfPossible();
    } finally {
      loadingPlots.value = false;
    }
  }

  Future<void> _prefill() async {
    prefilling.value = true;
    try {
      final tm.Datum? data = await _api.getTreeByIdCached(treeId!);
      if (data == null) {
        final isID = LanguageService.to.isId;
        Get.snackbar(
          'Error',
          isID ? 'Gagal memuat data pohon' : 'Failed to load tree data',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final tn = data.treeName?.trim();
      nameC.text = (tn == null || tn.isEmpty) ? '-' : tn;

      final sp = data.species?.trim();
      selectedSpecies.value = speciesOptions.contains(sp) ? sp : null;
      speciesC.text = sp ?? '';
      if (data.plantingDate != null) plantedAt.value = data.plantingDate!;

      final remotePath =
          (data.latestMonitoring?.photoPath?.isNotEmpty ?? false)
              ? data.latestMonitoring!.photoPath
              : data.photoPath;
      networkPhotoUrl.value = _resolvePhotoUrl(remotePath);

      final pId = data.plot?.id;
      final plotName = data.plot?.plotName ?? '-';
      final farmerName = data.farmer?.farmerName ?? '-';
      if (pId != null) {
        final match = plots.where((e) => e.id == pId).toList();
        selectedPlot.value = match.isNotEmpty
            ? match.first
            : PlotOption(id: pId, code: plotName, farmerName: farmerName);
      }

      final lm = data.latestMonitoring;
      if (lm != null) {
        lat.value = _toDoubleFlexible(lm.latitude);
        lng.value = _toDoubleFlexible(lm.longitude);
        gpsAccuracy.value = _toDoubleFlexible(lm.accuracyM);
      } else {
        lat.value = _toDoubleFlexible(data.latitude);
        lng.value = _toDoubleFlexible(data.longitude);
        gpsAccuracy.value = _toDoubleFlexible(data.accuracyM);
      }
      gpsTimestamp.value = null;
    } catch (e) {
      final isID = LanguageService.to.isId;
      Get.snackbar(
        'Error',
        isID ? 'Gagal prefill: $e' : 'Failed to prefill: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      prefilling.value = false;
    }
  }

  double? _toDoubleFlexible(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim().replaceAll(',', '.');
      return double.tryParse(s);
    }
    return null;
  }

  static String? _resolvePhotoUrl(String? v) {
    if (v == null) return null;

    String s = v.trim();

    if (s.isEmpty) return null;

    const base = 'https://app.nbsvworldwide.com';

    // Jika sudah full URL
    if (s.startsWith('http://') || s.startsWith('https://')) {
      final u = Uri.tryParse(s);

      if (u == null) return s;

      // Ganti localhost ke domain production
      if (u.host == 'localhost' || u.host == '127.0.0.1') {
        String path = u.path;

        // Tambahkan storage jika belum ada
        path = path.replaceFirst(RegExp(r'^/+'), '');

        if (!path.startsWith('storage/')) {
          path = 'storage/$path';
        }

        return Uri(
          scheme: 'https',
          host: 'app.nbsvworldwide.com',
          path: '/$path',
        ).toString();
      }

      return s;
    }

    // Hapus slash depan
    s = s.replaceFirst(RegExp(r'^/+'), '');

    // Tambahkan storage jika belum ada
    if (!s.startsWith('storage/')) {
      s = 'storage/$s';
    }

    return '$base/$s';
  }

  Future<void> pickImage(BuildContext context) async {
    gpsSampleCount.value = 0;

    // Serialize the location permission prompt before launching the camera
    // (Android refuses overlapping permission requests with empty grantResults).
    await ensureLocationPermission();

    // Mulai sampling GPS paralel dengan pembukaan kamera, supaya pengguna
    // tidak menunggu sekuensial. Stream tetap berjalan di background;
    // dialog progress baru dibuka setelah foto selesai diambil.
    final session = startGpsSampling();
    final progressSub = session.progress.listen(
      (p) => gpsSampleCount.value = p.sampleCount,
      onError: (_) {},
    );

    // Tandai bahwa kita sedang mengambil foto tree. Jika Android menghancurkan
    // activity saat kamera terbuka (low memory) dan app dingin-restart ke home,
    // Splash akan membuka kembali layar ini pakai marker ini, lalu
    // _recoverLostImage() memulihkan foto + GPS. Marker dibersihkan begitu
    // kamera kembali (berarti activity tidak mati).
    await _setPendingCaptureMarker();

    if (!context.mounted) {
      session.cancel();
      await progressSub.cancel();
      await _clearPendingCaptureMarker();
      return;
    }

    // In-app camera (not the system camera) so Android does not kill our
    // process for memory while it is open — the parallel GPS session and the
    // accuracy dialog below survive the capture.
    final path = await captureInAppPhoto(context,
        title: LanguageService.to.isId ? 'Foto Pohon' : 'Tree Photo');
    await _clearPendingCaptureMarker();
    if (path == null) {
      session.cancel();
      await progressSub.cancel();
      return;
    }

    // Set image path immediately so save() always sees it,
    // even if the user taps submit before GPS resolves.
    await _persistPickedImage(XFile(path));

    if (!context.mounted) {
      session.cancel();
      await progressSub.cancel();
      return;
    }

    final result = await showGpsLoadingDialog(context, session: session);
    await progressSub.cancel();
    final pos = result.position;

    if (pos != null) {
      lat.value = pos.latitude;
      lng.value = pos.longitude;
      gpsAccuracy.value = pos.accuracy;
      gpsTimestamp.value = DateTime.now();
    } else {
      gpsTimestamp.value = null;
      gpsAccuracy.value = null;
    }

    final msg = gpsResultMessage(result);
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Simpan foto hasil capture ke folder dokumen aplikasi dan tandai
  /// sebagai foto lokal yang aktif.
  Future<void> _persistPickedImage(XFile x) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/tree_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final fileName = 'tree_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${photosDir.path}/$fileName');
    final data = await x.readAsBytes();
    await dest.writeAsBytes(data);

    localImagePath.value = dest.path;
    networkPhotoUrl.value = null;
  }

  /// Saat kamera terbuka, Android bisa mematikan activity aplikasi untuk
  /// membebaskan memori. Foto yang sudah diambil lalu "hilang" dan harus
  /// dipulihkan via [ImagePicker.retrieveLostData] (khusus Android).
  Future<void> _recoverLostImage() async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;
      await _persistPickedImage(lost.file!);

      // Sesi GPS yang berjalan paralel ikut mati bersama activity, jadi ambil
      // koordinat secara senyap di latar belakang supaya foto yang dipulihkan
      // tetap memiliki lokasi.
      if (lat.value == null) {
        final session = startGpsSampling();
        final r = await session.result;
        final pos = r.position;
        if (pos != null) {
          lat.value = pos.latitude;
          lng.value = pos.longitude;
          gpsAccuracy.value = pos.accuracy;
          gpsTimestamp.value = DateTime.now();
        }
      }
    } catch (_) {
      // Abaikan kegagalan pemulihan—bukan error fatal.
    }
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
      initialDate: plantedAt.value,
    );
    if (picked != null) plantedAt.value = picked;
  }

  Future<void> save(BuildContext context, {bool addAnother = false}) async {
    if (loading.value) return;

    if (selectedPlot.value == null) await _autoSelectPlotIfPossible();

    if (!context.mounted) return;
    if (!form.currentState!.validate()) return;

    if (selectedPlot.value == null) {
      final isID = LanguageService.to.isId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isID
                ? 'Tidak ada data lahan tersedia offline. '
                    'Buka sekali saat online atau pilih lahan saat tersedia.'
                : 'No plot data available offline. '
                    'Open once while online, or pick a plot when available.',
          ),
        ),
      );
      return;
    }

    loading.value = true;
    const safeTreeName = '-';

    try {
      if (treeId == null) {
        final res = await _api.addTreeOfflineFirst(
          plotId: selectedPlot.value!.id,
          treeName: safeTreeName,
          species: selectedSpecies.value,
          plantingDate: plantedAt.value,
          latitude: lat.value,
          longitude: lng.value,
          accuracyM: gpsAccuracy.value,
          photoPath: localImagePath.value,
        );

        await _saveLastPlot(selectedPlot.value!);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(res.message))));

        if (addAnother) {
          nameC.text = '-';
          speciesC.clear();
          selectedSpecies.value = null;
          localImagePath.value = null;
          networkPhotoUrl.value = null;
          plantedAt.value = DateTime.now();
          lat.value = null;
          lng.value = null;
          gpsTimestamp.value = null;
          gpsAccuracy.value = null;
          gpsSampleCount.value = 0;
          loading.value = false;
          return;
        } else {
          Navigator.pop(context, true);
          _deleteSelf();
        }
      } else {
        final res = await _api.editTreeOfflineFirst(
          id: treeId!,
          treeName: safeTreeName,
          species: selectedSpecies.value ?? speciesC.text.trim(),
          plantingDate: plantedAt.value,
          latitude: lat.value,
          longitude: lng.value,
          accuracyM: gpsAccuracy.value,
          photoPath: localImagePath.value,
        );

        if (selectedPlot.value != null) {
          await _saveLastPlot(selectedPlot.value!);
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(res.message))));
        Navigator.pop(context, true);
        _deleteSelf();
      }
    } catch (e) {
      if (!context.mounted) return;
      final isID = LanguageService.to.isId;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isID ? 'Gagal menyimpan: $e' : 'Failed to save: $e')));
    } finally {
      loading.value = false;
    }
  }
}
