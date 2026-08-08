import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/screens/widgets/gps_loading_dialog.dart';
import 'package:traceability_app/screens/widgets/in_app_camera_screen.dart';
import 'package:traceability_app/services/gps_sampler.dart';
import 'package:traceability_app/services/language_service.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class PolyPoint {
  final LatLng latLng;
  final String? localPhotoPath;
  final String? remotePhotoPath;
  final double? accuracyM;
  final DateTime? capturedAt;

  const PolyPoint({
    required this.latLng,
    this.localPhotoPath,
    this.remotePhotoPath,
    this.accuracyM,
    this.capturedAt,
  });

  bool get hasAnyPhoto =>
      (localPhotoPath != null && localPhotoPath!.isNotEmpty) ||
      (remotePhotoPath != null && remotePhotoPath!.isNotEmpty);
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class KthPolygonController extends GetxController {
  final _plotApi = PlotApi();
  final mapController = MapController();

  int? plotId;
  bool isDraft = false;
  int? farmerId;
  String? farmerName;
  LatLng center = const LatLng(-2.21, 113.92);
  double zoom = 13;

  final points = <PolyPoint>[].obs;
  final isLoading = false.obs;
  final isDirty = false.obs;

  // Set when this screen was reopened by SplashController after Android killed
  // the activity mid-camera. Affects how a draft polygon is saved (the add-plot
  // parent screen is gone, so we continue there instead of popping to it).
  bool _resumed = false;

  // Marker/snapshot keys — kept in sync with SplashController.
  static const kPendingPolygonCaptureKey = 'pending_polygon_capture';
  static const _kPolygonSnapshotKey = 'ppc_snapshot_v1';

  // ---------------------------------------------------------------------------
  // Init from route args (call once from build)
  // ---------------------------------------------------------------------------

  void initFromArgs(dynamic args) {
    // Reopened after an Android camera-kill: restore the in-progress polygon
    // (points + photos) from the snapshot instead of parsing route args.
    if (args is Map && args['__resumePolygon'] == true) {
      _resumePolygon();
      return;
    }

    // reset state agar tidak terbawa dari plot sebelumnya
    plotId = null;
    isDraft = false;
    farmerId = null;
    farmerName = null;
    _resumed = false;
    points.clear();
    isDirty.value = false;
    isLoading.value = false;
    center = const LatLng(-2.21, 113.92);
    zoom = 13;

    String wkt = '';

    if (args is Map) {
      final m = Map<String, dynamic>.from(args);
      isDraft = m['draft'] == true;
      farmerId = _toInt(m['farmerId'] ?? m['farmer_id']);
      farmerName = (m['farmerName'] ?? m['farmer_name'])?.toString();
      final anyId =
          m['plotId'] ?? m['id'] ?? (m['plot'] is Map ? m['plot']['id'] : null);
      plotId = _toInt(anyId);

      wkt = (m['polygonWkt'] ?? m['polygon'] ?? '').toString();

      final lat = _tryDouble((m['latitude'] ?? '').toString());
      final lng = _tryDouble((m['longitude'] ?? '').toString());
      if (lat != null && lng != null && _coordInRange(lat, lng)) {
        center = LatLng(lat, lng);
        zoom = 15;
      }

      final plot = m['plot'];
      if (plot is Map) {
        final lat2 = _tryDouble((plot['latitude'] ?? '').toString());
        final lng2 = _tryDouble((plot['longitude'] ?? '').toString());
        if (lat2 != null && lng2 != null && _coordInRange(lat2, lng2)) {
          center = LatLng(lat2, lng2);
          zoom = 15;
        }
      }
    } else if (args is String) {
      wkt = args;
    }

    final parsed = _parseWkt(wkt);
    final hasWktPolygon = parsed.length >= 3;
    if (parsed.isNotEmpty) {
      points.addAll(parsed.map((p) => PolyPoint(latLng: p)));
      final c = _centroid(parsed);
      if (c != null) {
        center = c;
        zoom = 16;
      }
    }

    // Polygon WKT (dari record plot) adalah sumber kebenaran untuk geometri.
    // Kalau ada WKT valid, jangan timpa — API hanya dipakai untuk memperkaya
    // titik dengan photo/accuracy/captured_at (match by seq).
    // Kalau plot belum punya WKT, baru load full dari API.
    // Skip API entirely dalam mode draft (plot belum dibuat).
    if (!isDraft && plotId != null) {
      if (hasWktPolygon) {
        _enrichPointsFromApi(plotId!);
      } else {
        _loadPointsFromApi(plotId!);
      }
    }
    PlotApi.startAutoSyncListener();
  }

  /// Pertahankan koordinat WKT, tapi isi photo/accuracy/captured_at dari API
  /// (match per index seq). Tidak menimpa geometri.
  Future<void> _enrichPointsFromApi(int id) async {
    try {
      final list = await _plotApi.getPolygonPoints(id);
      if (list.isEmpty) return;
      final byIndex = <int, PlotPolygonPoint>{};
      for (final p in list) {
        byIndex[p.seq - 1] = p;
      }
      final merged = <PolyPoint>[];
      for (int i = 0; i < points.length; i++) {
        final base = points[i];
        final api = byIndex[i];
        if (api == null) {
          merged.add(base);
        } else {
          merged.add(PolyPoint(
            latLng: base.latLng, // <-- WKT tetap menang untuk posisi
            localPhotoPath: base.localPhotoPath,
            remotePhotoPath: api.remotePhotoPath,
            accuracyM: api.accuracyM ?? base.accuracyM,
            capturedAt: api.capturedAt ?? base.capturedAt,
          ));
        }
      }
      points.assignAll(merged);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _tryDouble(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  bool _coordInRange(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 && lat <= 90 &&
      lng >= -180 && lng <= 180 &&
      !(lat == 0.0 && lng == 0.0);

  bool _sameLatLng(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-10 &&
      (a.longitude - b.longitude).abs() < 1e-10;

  List<LatLng> _parseWkt(String wkt) {
    final s = wkt.trim();
    if (s.isEmpty) return [];
    final up = s.toUpperCase();
    if (!up.startsWith('POLYGON((') || !up.endsWith('))')) return [];

    final inner = s.substring(s.indexOf('((') + 2, s.lastIndexOf('))'));
    final pts = <LatLng>[];
    for (final p in inner.split(',')) {
      final t = p.trim().split(RegExp(r'\s+'));
      if (t.length < 2) continue;
      final lng = _tryDouble(t[0]);
      final lat = _tryDouble(t[1]);
      if (lat == null || lng == null || !_coordInRange(lat, lng)) continue;
      pts.add(LatLng(lat, lng));
    }
    if (pts.length >= 2 && _sameLatLng(pts.first, pts.last)) pts.removeLast();
    return pts;
  }

  String buildWkt() {
    if (points.length < 3) return '';
    final ring = [...points.map((e) => e.latLng), points.first.latLng];
    final coords = ring
        .map((p) => '${_fmt(p.longitude)} ${_fmt(p.latitude)}')
        .join(', ');
    return 'POLYGON(($coords))';
  }

  String _fmt(double v) =>
      v.toStringAsFixed(6).replaceAll(RegExp(r'([.]*0+)$'), '');

  LatLng? _centroid(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    double lat = 0, lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  // ---------------------------------------------------------------------------
  // GPS / Camera
  // ---------------------------------------------------------------------------

  Future<File?> _takePhoto(BuildContext context) async {
    // In-app camera keeps the capture inside our process, so Android will not
    // kill the app for memory while it is open and the parallel GPS sampling
    // survives.
    final path = await captureInAppPhoto(context,
        title: LanguageService.to.isId ? 'Foto Titik' : 'Point Photo');
    if (path == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir =
        Directory('${docsDir.path}/polygon_point_photos');
    if (!await photosDir.exists()) await photosDir.create(recursive: true);

    final dest = File(
        '${photosDir.path}/poly_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(path).copy(dest.path);
    return dest;
  }

  // ---------------------------------------------------------------------------
  // Camera-kill recovery (Android): persist the in-progress polygon before the
  // camera opens; SplashController reopens this screen after a cold restart.
  // ---------------------------------------------------------------------------

  Future<void> _savePolygonResumeSnapshot() async {
    final p = await SharedPreferences.getInstance();
    final snap = {
      'plotId': plotId,
      'isDraft': isDraft,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'centerLat': center.latitude,
      'centerLng': center.longitude,
      'zoom': zoom,
      'points': points
          .map((e) => {
                'lat': e.latLng.latitude,
                'lng': e.latLng.longitude,
                'localPhotoPath': e.localPhotoPath,
                'remotePhotoPath': e.remotePhotoPath,
                'accuracyM': e.accuracyM,
                'capturedAt': e.capturedAt?.toIso8601String(),
              })
          .toList(),
    };
    await p.setString(_kPolygonSnapshotKey, jsonEncode(snap));
    await p.setBool(kPendingPolygonCaptureKey, true);
  }

  Future<void> _clearPolygonCaptureMarker() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(kPendingPolygonCaptureKey);
  }

  Future<void> _resumePolygon() async {
    // Baseline reset.
    plotId = null;
    isDraft = false;
    farmerId = null;
    farmerName = null;
    points.clear();
    isDirty.value = false;
    isLoading.value = false;
    center = const LatLng(-2.21, 113.92);
    zoom = 13;
    _resumed = true;

    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPolygonSnapshotKey);
    await p.remove(kPendingPolygonCaptureKey);
    await p.remove(_kPolygonSnapshotKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final snap = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        plotId = _toInt(snap['plotId']);
        isDraft = snap['isDraft'] == true;
        farmerId = _toInt(snap['farmerId']);
        farmerName = snap['farmerName']?.toString();
        final cLat = (snap['centerLat'] as num?)?.toDouble();
        final cLng = (snap['centerLng'] as num?)?.toDouble();
        if (cLat != null && cLng != null && _coordInRange(cLat, cLng)) {
          center = LatLng(cLat, cLng);
          zoom = (snap['zoom'] as num?)?.toDouble() ?? 16;
        }
        final restored = <PolyPoint>[];
        for (final e in (snap['points'] as List? ?? const [])) {
          final m = Map<String, dynamic>.from(e as Map);
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          if (lat == null || lng == null || !_coordInRange(lat, lng)) continue;
          restored.add(PolyPoint(
            latLng: LatLng(lat, lng),
            localPhotoPath: m['localPhotoPath'] as String?,
            remotePhotoPath: m['remotePhotoPath'] as String?,
            accuracyM: (m['accuracyM'] as num?)?.toDouble(),
            capturedAt: m['capturedAt'] == null
                ? null
                : DateTime.tryParse(m['capturedAt'].toString()),
          ));
        }
        points.assignAll(restored);
        if (restored.isNotEmpty) isDirty.value = true;
      } catch (_) {}
    }

    // Recover the photo taken just before the kill and append it as a new point.
    await _recoverLostPointPhoto();

    final c = _centroid(points.map((e) => e.latLng).toList());
    if (c != null) {
      center = c;
      if (zoom < 16) zoom = 16;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          mapController.move(center, zoom);
        } catch (_) {}
      });
    }
  }

  Future<void> _recoverLostPointPhoto() async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/polygon_point_photos');
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      final dest = File(
          '${photosDir.path}/poly_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await dest.writeAsBytes(await lost.file!.readAsBytes());

      // GPS session died with the activity — take a fresh silent fix.
      final session = startGpsSampling();
      final r = await session.result;
      final pos = r.position;
      if (pos != null && _coordInRange(pos.latitude, pos.longitude)) {
        points.add(PolyPoint(
          latLng: LatLng(pos.latitude, pos.longitude),
          localPhotoPath: dest.path,
          accuracyM: pos.accuracy,
          capturedAt: DateTime.now(),
        ));
        isDirty.value = true;
      }
    } catch (_) {
      // Recovery is best-effort.
    }
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _loadPointsFromApi(int id) async {
    try {
      final list = await _plotApi.getPolygonPoints(id);
      if (list.isEmpty) return;

      final apiPoints = list
          .map((p) => PolyPoint(
                latLng: LatLng(p.latitude, p.longitude),
                remotePhotoPath: p.remotePhotoPath,
                accuracyM: p.accuracyM,
                capturedAt: p.capturedAt,
              ))
          .toList();

      // Tolak data API yang degenerate (semua titik di koordinat yang sama,
      // mis. data test dari emulator yang nempel di Google HQ).
      // Kalau API tidak punya minimal 3 titik UNIK, pertahankan polygon dari WKT args.
      final unique = <String>{};
      for (final p in apiPoints) {
        unique.add(
            '${p.latLng.latitude.toStringAsFixed(6)},${p.latLng.longitude.toStringAsFixed(6)}');
      }
      if (unique.length < 3) return;

      points.assignAll(apiPoints);
      isDirty.value = false;

      // Recenter map ke centroid polygon yang baru dimuat dari API.
      final latlngs = points.map((e) => e.latLng).toList();
      final c = _centroid(latlngs);
      if (c != null) {
        center = c;
        zoom = 17;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(center, zoom);
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> addPoint(BuildContext context) async {
    if (isLoading.value) return;

    // Serialize the location permission prompt before launching the camera
    // (Android refuses overlapping permission requests with empty grantResults).
    await ensureLocationPermission();

    // Mulai sampling GPS paralel dengan kamera supaya tidak menunggu sekuensial.
    // Dialog progress baru dibuka setelah foto selesai diambil.
    final session = startGpsSampling();

    // Persist the in-progress polygon so it survives an Android camera-kill.
    // Cleared as soon as the camera returns (activity was not destroyed).
    await _savePolygonResumeSnapshot();
    if (!context.mounted) {
      session.cancel();
      await _clearPolygonCaptureMarker();
      return;
    }
    final file = await _takePhoto(context);
    await _clearPolygonCaptureMarker();
    if (file == null) {
      session.cancel();
      return;
    }

    if (!context.mounted) {
      session.cancel();
      return;
    }

    final result = await showGpsLoadingDialog(context, session: session);
    final pos = result.position;

    final isID = LanguageService.to.isId;
    if (pos == null) {
      final msg = gpsResultMessage(result) ??
          (isID
              ? 'Lokasi tidak tersedia. Aktifkan GPS dan izinkan akses lokasi.'
              : 'Location unavailable. Enable GPS and grant location permission.');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }
    if (!_coordInRange(pos.latitude, pos.longitude)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isID
                ? 'Koordinat GPS tidak valid.'
                : 'Invalid GPS coordinates.')));
      }
      return;
    }

    final newPt = LatLng(pos.latitude, pos.longitude);
    points.add(PolyPoint(
      latLng: newPt,
      localPhotoPath: file.path,
      accuracyM: pos.accuracy,
      capturedAt: DateTime.now(),
    ));
    isDirty.value = true;
    center = newPt;
    if (zoom < 17) zoom = 17;
    mapController.move(newPt, zoom);

    final warn = gpsResultMessage(result);
    if (warn != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warn)));
    }
  }

  void undo() {
    if (points.isEmpty) return;
    points.removeLast();
    isDirty.value = true;
  }

  void clear() {
    if (points.isEmpty) return;
    points.clear();
    isDirty.value = true;
  }

  void removeAt(int idx) {
    if (idx < 0 || idx >= points.length) return;
    points.removeAt(idx);
    isDirty.value = true;
  }

  Future<void> save(BuildContext context) async {
    if (isLoading.value) return;
    final isID = LanguageService.to.isId;

    final wkt = buildWkt();
    if (wkt.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isID
                ? 'Polygon minimal butuh 3 titik.'
                : 'Polygon needs at least 3 points.')));
      }
      return;
    }

    // Mode draft: plot belum dibuat. Hanya return WKT ke caller (add-plot
    // flow). Foto per-titik tidak bisa di-upload tanpa plotId — itu di-handle
    // setelah plot pertama kali tersimpan.
    if (isDraft || plotId == null) {
      isDirty.value = false;
      if (_resumed) {
        // Reopened standalone after a camera-kill — the add-plot screen that
        // would receive this WKT is gone. Continue there with it prefilled.
        if (context.mounted) {
          Get.offNamed('/kth_add_plot', arguments: {
            'farmerId': farmerId ?? 0,
            'farmerName': farmerName,
            'polygonWkt': wkt,
          });
        }
      } else if (context.mounted) {
        Navigator.pop(context, wkt);
      }
      return;
    }

    isLoading.value = true;
    try {
      final payload = <PlotPolygonPoint>[
        for (int i = 0; i < points.length; i++)
          PlotPolygonPoint(
            seq: i + 1,
            latitude: points[i].latLng.latitude,
            longitude: points[i].latLng.longitude,
            capturedAt: points[i].capturedAt ?? DateTime.now(),
            accuracyM: points[i].accuracyM,
            source: 'mobile',
          ),
      ];

      final r1 = await _plotApi.replacePolygonPointsOfflineFirst(
          plotId: plotId!, points: payload);

      int queuedPhoto = 0;
      for (int i = 0; i < points.length; i++) {
        final path = points[i].localPhotoPath;
        if (path == null || path.isEmpty) continue;
        final f = File(path);
        if (!await f.exists()) continue;
        final r2 = await _plotApi.uploadPolygonPointPhotoOfflineFirst(
            plotId: plotId!, seq: i + 1, filePath: path);
        if (r2.queued) queuedPhoto++;
      }

      await _plotApi.pushPlotOutbox();
      isDirty.value = false;

      if (context.mounted) {
        final msg = (queuedPhoto > 0 || r1.queued)
            ? (isID
                ? 'Tersimpan offline (${r1.outboxCount} antrian).'
                : 'Saved offline (${r1.outboxCount} queued).')
            : (isID
                ? 'Polygon & foto tersimpan.'
                : 'Polygon & photos saved.');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context, wkt);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isID ? 'Gagal menyimpan: $e' : 'Failed to save: $e')));
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> copyWkt(BuildContext context) async {
    final isID = LanguageService.to.isId;
    final wkt = buildWkt();
    if (wkt.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isID
                ? 'Belum ada polygon valid untuk di-copy.'
                : 'No valid polygon to copy yet.')));
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: wkt));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isID ? 'WKT disalin.' : 'WKT copied.')));
    }
  }

  Future<bool> confirmLeave(BuildContext context) async {
    if (!isDirty.value) return true;
    final isID = LanguageService.to.isId;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isID ? 'Keluar tanpa menyimpan?' : 'Leave without saving?'),
            content: Text(isID
                ? 'Perubahan polygon belum disimpan.'
                : 'Polygon changes have not been saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isID ? 'Batal' : 'Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isID ? 'Keluar' : 'Leave'),
              ),
            ],
          ),
        ).then((v) => v ?? false);
  }

  void showPointsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Obx(() => ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: points.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (_, i) {
                final p = points[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Colors.green.withValues(alpha: 0.12),
                      child: Text('${i + 1}',
                          style: const TextStyle(color: Colors.green)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lat: ${p.latLng.latitude.toStringAsFixed(6)}'),
                          Text('Lng: ${p.latLng.longitude.toStringAsFixed(6)}'),
                          if (p.accuracyM != null)
                            Text('Acc: ${p.accuracyM!.toStringAsFixed(1)} m'),
                          if (p.localPhotoPath != null)
                            const Text('Foto: lokal'),
                          if (p.remotePhotoPath != null)
                            const Text('Foto: server'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isLoading.value
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              removeAt(i);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                );
              },
            )),
      ),
    );
  }
}
