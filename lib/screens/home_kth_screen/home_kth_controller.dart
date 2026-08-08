import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/models/api/selling_api.dart';
import 'package:traceability_app/models/api/warehouse_api.dart';
import 'package:traceability_app/models/get_selling_by_kth_id.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/sync_service.dart';

class HomeKthController extends GetxController {
  final _wApi = WarehouseApi();
  final _sApi = SellingApi();

  final language = LanguageService.to.language;
  final kthName = ''.obs;
  final lastSyncDisplay = '-'.obs;
  final isOffline = false.obs;
  final isLoading = true.obs;
  final error = RxnString();
  final warehouseData = Rxn<GetWarehouseByKthId>();
  final sellingData = Rxn<GetSellingByKthId>();

  int _kthId = 0;
  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    _init();
    _watchConnectivity();
    // Start every module's outbox sync + flush anything queued offline, so a
    // reconnect (or opening the app already online) pushes all pending data.
    SyncService.startAll();
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    kthName.value = prefs.getString('name') ?? '';
    _kthId = prefs.getInt('id') ?? 0;
    await refresh();
  }

  Future<void> _watchConnectivity() async {
    final first = await Connectivity().checkConnectivity();
    isOffline.value = _isOfflineFrom(first);
    _connSub = Connectivity().onConnectivityChanged.listen((conn) {
      isOffline.value = _isOfflineFrom(conn);
    });
  }

  String _fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  bool _isOfflineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return true;
      return !list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn == ConnectivityResult.none;
    }
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    error.value = null;

    try {
      final warehouseFut = _wApi.getWarehouseByKthIdCached(_kthId);
      final sellingFut = _sApi.getSellingByKthIdCached(_kthId);

      final warehouse = await warehouseFut;
      final selling = await sellingFut;

      warehouseData.value = warehouse;
      sellingData.value = selling;

      final times = await Future.wait([
        _wApi.getWarehouseByKthCacheTime(_kthId),
        _sApi.getSellingByKthCacheTime(_kthId),
      ]);
      final latest = times.whereType<DateTime>().fold<DateTime?>(
            null,
            (prev, t) => prev == null || t.isAfter(prev) ? t : prev,
          );
      lastSyncDisplay.value = _fmtLastSync(latest);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
