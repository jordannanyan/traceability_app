import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:get/get.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart';
import 'package:traceability_app/screens/lahan_screen/lahan_screen_widget/plot_list_farmer_widget.dart';
import 'package:traceability_app/screens/lahan_screen/lahan_screen_widget/plot_map_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/offline_banner.dart';
import 'package:traceability_app/screens/widgets/stale_data_banner.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PlotScreen extends StatefulWidget {
  const PlotScreen({super.key});

  @override
  State<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends State<PlotScreen> {
  late Future<List<Datum>> _plotsFuture;

  bool _isOfflineView = false;
  bool _syncing = false;

  /// Kenapa daftar ini berisi apa yang ditampilkan.
  RefreshOutcome _refreshOutcome = RefreshOutcome.fresh;

  int? _farmerId;
  final _api = PlotApi();
  StreamSubscription<dynamic>? _connSub;

  @override
  void initState() {
    super.initState();
    PlotApi.startAutoSyncListener();
    _plotsFuture = _load();

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      final online = _isOnlineFrom(conn);
      final wasOffline = _isOfflineView;
      if (!mounted) return;
      setState(() => _isOfflineView = !online);
      if (wasOffline && online) _refresh();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
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

  Future<List<Datum>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _farmerId = prefs.getInt('id');
    if (_farmerId == null || _farmerId == 0) {
      final isID = LanguageService.to.isId;
      throw Exception(isID
          ? 'Farmer ID tidak ditemukan. Silakan login ulang.'
          : 'Farmer ID not found. Please log in again.');
    }

    final conn = await Connectivity().checkConnectivity();
    _isOfflineView = !_isOnlineFrom(conn);

    final result = await _api.getPlotByFarmerIdCached(_farmerId!);
    _refreshOutcome = result.outcome;
    return result.data.data;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _plotsFuture = next);
    await next;
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final isID = LanguageService.to.isId;
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!_isOnlineFrom(conn)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isID
                  ? 'Masih offline. Nyalakan internet lalu coba lagi.'
                  : 'Still offline. Turn on the internet and try again.')),
        );
        return;
      }

      final pushed = await _api.pushPlotOutbox();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pushed > 0
                ? (isID
                    ? 'Berhasil menyinkronkan $pushed aksi tertunda.'
                    : 'Synced $pushed pending action(s).')
                : (isID
                    ? 'Semua data sudah tersinkronkan.'
                    : 'All data already synced.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isID ? 'Gagal sinkron: $e' : 'Sync failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(isID),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Datum>>(
          future: _plotsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.xl),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snap.error.toString(),
                        style: ThemeTextStyle
                            .textStyleForthBold
                            .copyWith(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: Text(isID ? 'Coba Lagi' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final plots = snap.data ?? <Datum>[];

            return ListView(
              children: [
                // Offline banner
                if (_isOfflineView)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: OfflineBanner(
                      isID: isID,
                      margin: EdgeInsets.zero,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: StaleDataBanner(
                      outcome: _refreshOutcome,
                      isID: isID,
                      onRetry: _refresh,
                    ),
                  ),

                // Map + plot count
                _buildHeaderSection(plots, isID),

                // Plot cards
                PlotListFarmerWidget(
                  onViewSaprodi: (i, item) {
                    final plotId = item.id;
                    if (plotId != null) {
                      Navigator.pushNamed(context, '/saprodi',
                          arguments: plotId);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isID
                                ? 'Plot ID tidak ditemukan'
                                : 'Plot ID not found')),
                      );
                    }
                  },
                  onEditPlot: (i, item) async {
                    final changed = await Navigator.pushNamed(
                        context, '/edit_plot',
                        arguments: item);
                    if (changed == true && mounted) _refresh();
                  },
                  onTapPlot: (i, item) {},
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 0),
    );
    });
  }

  PreferredSizeWidget _buildAppBar(bool isID) {
    return AppBar(
      title: Text(
        isID ? 'Lahan Saya' : 'My Plots',
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      backgroundColor: const Color(0xFF169843),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D6B2E), Color(0xFF169843)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        _syncing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.sync),
                tooltip: isID ? 'Sinkronkan data' : 'Sync data',
                onPressed: _syncNow,
              ),
      ],
    );
  }

  Widget _buildHeaderSection(List<Datum> plots, bool isID) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: PlotMapFlutterMap(plots: plots),
          ),
          const SizedBox(height: 12),

          // Summary row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      ThemeColor.darkestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                      color: ThemeColor
                          .darkestGreen
                          .withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco_outlined,
                        size: 15, color: ThemeColor.darkestGreen),
                    const SizedBox(width: 6),
                    Text(
                      isID
                          ? '${plots.length} Plot Terdaftar'
                          : '${plots.length} Registered Plots',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.darkestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
