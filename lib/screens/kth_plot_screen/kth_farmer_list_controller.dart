import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/farmer_api.dart';
import 'package:traceability_app/models/get_farmers_by_kth_id.dart';
import 'package:traceability_app/services/language_service.dart';

class KthFarmerListController extends GetxController {
  final _api = FarmerApi();

  final searchController = TextEditingController();

  // Observables
  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final isLoading = false.obs;
  final isSyncing = false.obs;
  final lastSync = Rxn<DateTime>();
  final all = <GetFarmerByKthId>[].obs;
  final filtered = <GetFarmerByKthId>[].obs;
  final errorMessage = RxnString();

  int? _kthId;
  Timer? _debounce;
  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    _init();

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;

      isOfflineView.value = !online;

      if (wasOffline && online) {
        load();
      }
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _kthId = prefs.getInt('id');

      if (_kthId == null || _kthId == 0) {
        errorMessage.value = 'KTH ID tidak ditemukan. Silakan login ulang.';
        return;
      }

      await load();
      await FarmerApi.startAutoSyncListener();
    } catch (e) {
      errorMessage.value = e.toString();
    }
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

  String fmtLastSync(DateTime? d) {
    if (d == null) return '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)} ${months[d.month - 1]} ${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  List<GetFarmerByKthId> _applyFilter(List<GetFarmerByKthId> src, String q) {
    if (q.isEmpty) return List<GetFarmerByKthId>.from(src);
    final qq = q.toLowerCase();

    return src.where((e) {
      final name = (e.farmerName ?? '').toLowerCase();
      final hp = (e.noHp ?? '').toLowerCase();
      final nik = (e.nik ?? '').toLowerCase();
      final addr = (e.address ?? '').toLowerCase();
      final idStr = (e.id?.toString() ?? '').toLowerCase();

      return name.contains(qq) ||
          hp.contains(qq) ||
          nik.contains(qq) ||
          addr.contains(qq) ||
          idStr == qq;
    }).toList();
  }

  Future<void> load({String? search}) async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final list = await _api.getFarmersCached(
        kthId: _kthId,
        search: (search != null && search.trim().isNotEmpty)
            ? search.trim()
            : null,
      );

      final sorted = List<GetFarmerByKthId>.from(list);
      sorted.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

      final cacheTime =
          await _api.getFarmersCacheTime(kthId: _kthId, search: search);
      lastSync.value = cacheTime;

      all.assignAll(sorted);
      filtered.assignAll(_applyFilter(sorted, searchController.text.trim()));
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await load(search: v.trim().isNotEmpty ? v.trim() : null);
      filtered.assignAll(_applyFilter(all, v.trim()));
    });
  }

  Future<void> syncOutbox(BuildContext context) async {
    if (isSyncing.value) return;

    final messenger = ScaffoldMessenger.of(context);

    isSyncing.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      final online = _isOnlineFrom(conn);
      final isID = language.value == 'id';

      if (!online) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isID
                  ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                  : 'Still offline. Turn on internet and try again.',
            ),
          ),
        );
        return;
      }

      final pushed = await _api.pushFarmerOutbox();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pushed > 0
                ? (isID ? 'Tersinkron: $pushed aksi.' : 'Synced: $pushed action(s).')
                : (isID ? 'Outbox kosong.' : 'Outbox is empty.'),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      await load(
        search: searchController.text.trim().isEmpty
            ? null
            : searchController.text.trim(),
      );
    } catch (e) {
      final isID = language.value == 'id';
      messenger.showSnackBar(
        SnackBar(
          content: Text(isID ? 'Gagal sinkron: $e' : 'Sync failed: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      isSyncing.value = false;
    }
  }

  String subtitleFarmer(GetFarmerByKthId f) {
    final hp = (f.noHp ?? '').trim();
    final nik = (f.nik ?? '').trim();
    final addr = (f.address ?? '').trim();

    final parts = <String>[];
    if (hp.isNotEmpty) parts.add(hp);
    if (nik.isNotEmpty) parts.add(nik);
    if (addr.isNotEmpty) parts.add(addr);

    if (parts.isEmpty) return '-';
    return parts.join(' \u2022 ');
  }
}
