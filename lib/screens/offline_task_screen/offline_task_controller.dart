import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/offline_tasks.dart';
import 'package:traceability_app/services/language_service.dart';

class OfflineTaskController extends GetxController {
  final language = LanguageService.to.language;

  final isLoading = false.obs;
  final isSyncing = false.obs;
  final isOffline = false.obs;
  final tasks = <OfflineTask>[].obs;

  /// Jumlah antrean saat sesi upload terakhir dimulai. Persentase dihitung
  /// terhadap angka ini, supaya batang kemajuan naik saat item terkirim
  /// (kalau dibandingkan dengan sisa antrean saja, angkanya selalu 100%).
  final _batchTotal = 0.obs;
  final _batchDone = 0.obs;

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    load();
    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      isOffline.value = !_isOnlineFrom(conn);
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

  /// Jumlah yang masih menunggu.
  int get pendingCount => tasks.length;

  /// Yang bisa dikirim sekarang (pembelian & penjualan dibekukan).
  int get syncableCount => tasks.where((t) => t.canSync).length;

  int get frozenCount => pendingCount - syncableCount;

  /// Berapa persen dari pekerjaan sesi ini yang sudah terkirim, 0..1.
  ///
  /// Tanpa antrean sama sekali berarti tidak ada yang tertinggal — 100%.
  double get uploadedFraction {
    if (_batchTotal.value == 0) return syncableCount == 0 ? 1.0 : 0.0;
    return (_batchDone.value / _batchTotal.value).clamp(0.0, 1.0);
  }

  int get uploadedPercent => (uploadedFraction * 100).round();

  /// "3 dari 5 terkirim" — angka mentah untuk label di bawah batang kemajuan.
  int get batchDone => _batchDone.value;
  int get batchTotal => _batchTotal.value;

  Map<OfflineModule, List<OfflineTask>> get grouped {
    final map = <OfflineModule, List<OfflineTask>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.module, () => <OfflineTask>[]).add(t);
    }
    return map;
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      isOffline.value = !_isOnlineFrom(conn);
      tasks.assignAll(await OfflineTaskCenter.all());

      // Antrean kosong = tidak ada sesi upload yang sedang berjalan.
      if (syncableCount == 0) {
        _batchTotal.value = 0;
        _batchDone.value = 0;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncAll(BuildContext context) async {
    if (isSyncing.value) return;
    final isID = language.value == 'id';
    final messenger = ScaffoldMessenger.of(context);

    final conn = await Connectivity().checkConnectivity();
    if (!_isOnlineFrom(conn)) {
      isOffline.value = true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isID
                ? 'Masih offline. Sambungkan internet lalu coba lagi.'
                : 'Still offline. Connect to the internet and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final before = syncableCount;
    if (before == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isID ? 'Tidak ada data yang menunggu.' : 'Nothing is waiting.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    isSyncing.value = true;
    _batchTotal.value = before;
    _batchDone.value = 0;

    try {
      await OfflineTaskCenter.pushAll();
      await load();

      // Diukur dari sisa antrean, bukan dari angka yang dilaporkan push:
      // item yang ditolak server ikut hilang dari antrean, dan bagi pengguna
      // yang penting adalah berapa yang benar-benar sudah beres.
      final after = syncableCount;
      _batchTotal.value = before;
      _batchDone.value = (before - after).clamp(0, before);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            after == 0
                ? (isID
                      ? 'Selesai. $before data terkirim.'
                      : 'Done. $before item(s) uploaded.')
                : (isID
                      ? '${before - after} dari $before terkirim, sisa $after menunggu.'
                      : '${before - after} of $before uploaded, $after still waiting.'),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isID ? 'Gagal sinkron: $e' : 'Sync failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isSyncing.value = false;
    }
  }

  String fmtQueuedAt(DateTime d) {
    const idMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = language.value == 'id' ? idMonths : enMonths;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${m[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
