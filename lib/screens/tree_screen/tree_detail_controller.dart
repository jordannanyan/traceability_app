import 'dart:async';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/models/get_trees.dart' as tm;
import 'package:traceability_app/services/language_service.dart';

class TreeDetailController extends GetxController {
  final int treeId;
  TreeDetailController({required this.treeId});

  final _api = TreeApi();

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final tree = Rxn<tm.Datum>();
  final error = RxnString();

  final qrKey = GlobalKey();

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    _bootConnectivity();
    load();

    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) async {
      final online = conn != ConnectivityResult.none;
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) load();
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  bool _isOnlineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return false;
      return list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn != ConnectivityResult.none;
    }
  }

  Future<void> _bootConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final conn = await Connectivity().checkConnectivity();
      isOfflineView.value = !_isOnlineFrom(conn);
      final res = await _api.getTreeByIdCached(treeId);
      tree.value = res;
      if (res == null) {
        error.value = language.value == 'id'
            ? 'Data tidak ditemukan'
            : 'Data not found';
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  String fmtDate(DateTime? d) {
    if (d == null) return '-';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}';
  }

  String fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  double? toDoubleFlexible(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim().replaceAll(',', '.');
      return double.tryParse(s);
    }
    return null;
  }

  bool validCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  Future<void> downloadQr(BuildContext context) async {
    final isID = language.value == 'id';
    try {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              isID ? 'Izin menyimpan ditolak.' : 'Permission to save was denied.',
            ),
          ));
        }
        return;
      }

      final ctx = qrKey.currentContext;
      final boundary =
          ctx?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              isID ? 'QR belum siap. Coba lagi.' : 'QR not ready yet. Try again.',
            ),
          ));
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              isID ? 'Gagal membuat PNG.' : 'Failed to create PNG.',
            ),
          ));
        }
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final name = 'tree_$treeId.png';
      await Gal.putImageBytes(bytes, name: name);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            isID ? 'QR disimpan ke Galeri.' : 'QR saved to Gallery.',
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            isID ? 'Gagal mengunduh QR: $e' : 'Failed to download QR: $e',
          ),
        ));
      }
    }
  }
}
