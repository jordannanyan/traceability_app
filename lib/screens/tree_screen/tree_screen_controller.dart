import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';
import 'package:traceability_app/utils/utils.dart';

// ====== Public lite models ======
class FarmerLite {
  final int id;
  final String name;
  final String? kthName;

  FarmerLite({required this.id, required this.name, this.kthName});

  factory FarmerLite.fromAny(Map<String, dynamic> m) {
    final id =
        (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}') ?? 0;
    final name = (m['farmer_name'] ?? m['name'] ?? '').toString();
    String? kth;
    if (m['kth'] is Map) {
      kth =
          (m['kth']['kth_name'] ?? m['kth']['name'] ?? '').toString();
    } else if (m['kth_name'] != null) {
      kth = m['kth_name'].toString();
    }
    return FarmerLite(
      id: id,
      name: name.isEmpty ? 'Petani #$id' : name,
      kthName: kth,
    );
  }
}

class PlotLite {
  final int id;
  final String code;
  final String? latitude;
  final String? longitude;
  final String? landArea;
  final int? numberOfPlants;

  PlotLite({
    required this.id,
    required this.code,
    this.latitude,
    this.longitude,
    this.landArea,
    this.numberOfPlants,
  });

  factory PlotLite.fromAny(Map<String, dynamic> m) {
    final id =
        (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}') ?? 0;
    final code =
        (m['plot_name'] ?? m['name'] ?? m['code'] ?? m['plot_code'] ?? '')
            .toString();
    final String? landArea = m['land_area']?.toString();
    int? numberOfPlants;
    if (m['number_of_plants'] is int) {
      numberOfPlants = m['number_of_plants'] as int;
    } else if (m['number_of_plants'] != null) {
      numberOfPlants = int.tryParse(m['number_of_plants'].toString());
    }
    return PlotLite(
      id: id,
      code: code.isEmpty ? 'Plot #$id' : code,
      latitude: m['latitude']?.toString(),
      longitude: m['longitude']?.toString(),
      landArea: landArea,
      numberOfPlants: numberOfPlants,
    );
  }
}

// ====== Controller ======
class TreeController extends GetxController {
  final _api = TreeApi();
  late Dio _dio;

  final language = LanguageService.to.language;
  final isOfflineView = false.obs;
  final loadingFarmers = false.obs;
  final syncing = false.obs;
  final loadingRemote = false.obs;
  final searchText = ''.obs;

  final allFarmers = <FarmerLite>[].obs;
  final farmers = <FarmerLite>[].obs;
  final plotsByFarmer = <int, List<PlotLite>>{}.obs;
  final expanded = <int, bool>{}.obs;

  final searchC = TextEditingController();

  Timer? _debounce;
  StreamSubscription<dynamic>? _connSub;

  static String _farmersKey(int kthId) => 'cache_farmers_kth_$kthId';
  static String _farmersTsKey(int kthId) =>
      'cache_farmers_kth_${kthId}_ts';

  @override
  void onInit() {
    super.onInit();
    TreeApi.startAutoSyncListener();

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
        headers: {'Accept': 'application/json'},
      ),
    );

    _bootConnectivity();
    loadFarmers(initial: true);

    _connSub =
        Connectivity().onConnectivityChanged.listen((dynamic conn) async {
      final online = _isOnlineFrom(conn);
      final wasOffline = isOfflineView.value;
      isOfflineView.value = !online;
      if (wasOffline && online) loadFarmers();
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _debounce?.cancel();
    searchC.dispose();
    super.onClose();
  }

  Future<void> _bootConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);
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

  Future<Options> _auth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) throw Exception('Token not found');
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  Future<void> _saveFarmersCache(
      int kthId, List<Map<String, dynamic>> rows) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_farmersKey(kthId), jsonEncode(rows));
    await p.setInt(
        _farmersTsKey(kthId), DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>?> _loadFarmersCache(int kthId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_farmersKey(kthId));
    if (raw == null || raw.isEmpty) return null;
    final List list = jsonDecode(raw) as List;
    return list
        .map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> loadFarmers({bool initial = false, String? search}) async {
    loadingFarmers.value = initial;
    loadingRemote.value = true;
    if (initial) {
      farmers.clear();
      allFarmers.clear();
      expanded.clear();
      plotsByFarmer.clear();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final kthId = prefs.getInt('id') ?? 0;

      final conn = await Connectivity().checkConnectivity();
      final online = _isOnlineFrom(conn);
      isOfflineView.value = !online;

      List<FarmerLite> fetchedFarmers;

      if (online) {
        try {
          final opt = await _auth();
          final params = <String, dynamic>{
            if (kthId != 0) 'kth_id': kthId,
            if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
            'per_page': 200,
          };
          final resp = await _dio.get(
            '/farmers',
            options: opt,
            queryParameters: params,
          );
          if (resp.statusCode == 200) {
            final List dataList =
                (resp.data is Map && resp.data['data'] is List)
                    ? (resp.data['data'] as List)
                    : (resp.data as List);
            final rawRows = dataList
                .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map))
                .toList();
            await _saveFarmersCache(kthId, rawRows);
            fetchedFarmers =
                rawRows.map<FarmerLite>((m) => FarmerLite.fromAny(m)).toList()
                  ..sort((a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            unawaited(_api.prewarmPlotsAndTreesForFarmers(
              fetchedFarmers.map((f) => f.id).toList(),
              treesPerPage: 400,
            ));
          } else {
            throw Exception('HTTP ${resp.statusCode}');
          }
        } catch (_) {
          final cached = await _loadFarmersCache(kthId);
          if (cached == null) rethrow;
          fetchedFarmers =
              cached.map<FarmerLite>((m) => FarmerLite.fromAny(m)).toList()
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }
      } else {
        final cached = await _loadFarmersCache(kthId);
        fetchedFarmers =
            (cached ?? const <Map<String, dynamic>>[])
                .map<FarmerLite>((m) => FarmerLite.fromAny(m))
                .toList()
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      final filtered =
          _applyFarmerFilter(fetchedFarmers, searchC.text.trim());
      allFarmers.value = fetchedFarmers;
      farmers.value = filtered;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memuat data petani: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      loadingFarmers.value = false;
      loadingRemote.value = false;
    }
  }

  List<FarmerLite> _applyFarmerFilter(List<FarmerLite> src, String q) {
    if (q.isEmpty) return List<FarmerLite>.from(src);
    final qq = q.toLowerCase();
    return src.where((f) => f.name.toLowerCase().contains(qq)).toList();
  }

  void onSearchChanged(String v) {
    searchText.value = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await loadFarmers(search: v.trim().isEmpty ? null : v.trim());
      farmers.value = _applyFarmerFilter(allFarmers.toList(), v.trim());
    });
  }

  Future<void> loadPlotsForFarmer(int farmerId) async {
    if (plotsByFarmer.containsKey(farmerId)) return;
    try {
      final list = await _api.getPlotsByFarmerIdCached(farmerId);
      final plots = list
          .map<PlotLite>((e) => PlotLite.fromAny(e))
          .toList()
        ..sort(
            (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      plotsByFarmer[farmerId] = plots;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memuat lahan petani #$farmerId: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void toggleExpanded(int farmerId, bool open) {
    expanded[farmerId] = open;
    if (open) loadPlotsForFarmer(farmerId);
  }

  Future<void> syncNow(BuildContext context) async {
    if (syncing.value) return;
    syncing.value = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!_isOnlineFrom(conn)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              language.value == 'id'
                  ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                  : 'Still offline. Turn on internet and try again.',
            ),
          ));
        }
        return;
      }
      final before = await _api.getTreeOutboxCount();
      final pushed = await _api.pushTreeOutbox();
      final after = await _api.getTreeOutboxCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              syncResultMessage(before: before, pushed: pushed, after: after)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        final isID = language.value == 'id';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isID ? 'Gagal sinkron: $e' : 'Sync failed: $e')));
      }
    } finally {
      syncing.value = false;
    }
  }
}
