import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_plot_by_farmer_id.dart' as plot_list;
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/offline_banner_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_tile_widget.dart';
import 'package:traceability_app/screens/lahan_screen/lahan_screen_widget/plot_map_widget.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class KthPlotScreen extends StatelessWidget {
  final int farmerId;
  final String? farmerName;

  const KthPlotScreen({super.key, required this.farmerId, this.farmerName});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      KthPlotController(farmerId: farmerId, farmerName: farmerName),
      tag: '$farmerId',
    );

    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final farmerTitle = farmerName?.trim();
      final title = (farmerTitle == null || farmerTitle.isEmpty)
          ? (isID ? 'Daftar Plot Petani' : 'Farmer Plot List')
          : farmerTitle;

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(title, c, context, isID),
      body: RefreshIndicator(
        onRefresh: c.refresh,
        child: Obx(() {
          if (c.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (c.error.value != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      c.error.value!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: c.refresh,
                      child: Text(isID ? 'Coba Lagi' : 'Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final plots = List<plot_list.Datum>.from(c.plots);
          final lastSync = c.fmtLastSync(c.lastSync.value);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Offline banner
              if (c.isOfflineView.value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: KthOfflineBannerWithSync(c: c, ctx: context),
                ),

              // Map + stats
              _StatsCard(plots: plots, lastSync: lastSync, isID: isID),

              // Section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Text(
                      isID ? 'Daftar Plot' : 'Plot List',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeColor
                            .darkestGreen
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Radii.xl),
                      ),
                      child: Text(
                        '${plots.length} ${isID ? 'plot' : 'plots'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.darkestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Plot cards or empty state
              if (plots.isEmpty)
                _EmptyState(isID: isID)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: plots.asMap().entries.map((e) {
                      return PlotCard(
                        item: e.value,
                        idx: e.key,
                        c: c,
                        ctx: context,
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 80), // FAB clearance
            ],
          );
        }),
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => c.goAddPlot(context),
          backgroundColor: ThemeColor.darkestGreen,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(isID ? 'Tambah Plot' : 'Add Plot',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(
      String title, KthPlotController c, BuildContext context, bool isID) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white),
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
        Obx(() => c.isSyncing.value
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
                onPressed: () => c.syncNow(context),
              )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats card — map + count chip + last sync
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  final List<plot_list.Datum> plots;
  final String lastSync;
  final bool isID;

  const _StatsCard(
      {required this.plots, required this.lastSync, required this.isID});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PlotMapFlutterMap(plots: plots),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                      color:
                          ThemeColor.darkestGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terrain_outlined,
                        size: 13, color: ThemeColor.darkestGreen),
                    const SizedBox(width: 5),
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
              const SizedBox(width: 10),
              const Icon(Icons.history, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isID ? 'Sinkron: $lastSync' : 'Synced: $lastSync',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool isID;
  const _EmptyState({required this.isID});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.terrain_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isID ? 'Belum ada plot' : 'No plots yet',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            isID
                ? 'Tambah plot dengan tombol di bawah'
                : 'Add a plot using the button below',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
