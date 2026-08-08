import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_farmer_list_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/farmer_tile_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/offline_banner_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/stale_data_banner.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class KthFarmerListScreen extends StatelessWidget {
  const KthFarmerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => KthFarmerListController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(c, context),
      body: RefreshIndicator(
        onRefresh: () => c.load(
          search: c.searchController.text.trim().isEmpty
              ? null
              : c.searchController.text.trim(),
        ),
        child: Obx(() {
          if (c.errorMessage.value != null && c.all.isEmpty) {
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
                      c.errorMessage.value!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: c.load,
                      child: Text(c.language.value == 'id'
                          ? 'Coba Lagi'
                          : 'Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (c.isLoading.value && c.all.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final isID = c.language.value == 'id';
          final isOfflineView = c.isOfflineView.value;
          final lastSync = c.fmtLastSync(c.lastSync.value);
          final filtered = c.filtered.toList();
          final total = c.all.length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Offline banner
              if (isOfflineView)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: KthOfflineBanner(isID: isID),
                ),

              // Online but the refresh did not go through — say so instead of
              // passing stored rows off as current.
              if (!isOfflineView)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: StaleDataBanner(
                    outcome: c.refreshOutcome.value,
                    isID: isID,
                    onRetry: () => c.load(
                      search: c.searchController.text.trim().isEmpty
                          ? null
                          : c.searchController.text.trim(),
                    ),
                  ),
                ),

              // Stats card
              _StatsCard(total: total, isID: isID, lastSync: lastSync),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(c: c, isID: isID),
              ),

              // Loading stripe
              if (c.isLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              // Farmer cards or empty state
              if (filtered.isEmpty)
                _EmptyState(isID: isID)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    children: filtered.map((f) {
                      final farmerId = f.id;
                      final farmerName = (f.farmerName ?? '-').trim();
                      return FarmerCard(
                        farmer: f,
                        subtitle: c.subtitleFarmer(f),
                        isID: isID,
                        onTap: (farmerId == null || farmerId == 0)
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KthPlotScreen(
                                      farmerId: farmerId,
                                      farmerName: farmerName,
                                    ),
                                  ),
                                ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        }),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 0),
    );
  }

  PreferredSizeWidget _buildAppBar(
      KthFarmerListController c, BuildContext context) {
    return AppBar(
      title: Obx(() => Text(
            c.language.value == 'id' ? 'Daftar Petani' : 'Farmers',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          )),
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
                tooltip: 'Sinkronkan data',
                onPressed: () => c.syncOutbox(context),
              )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats card
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  final int total;
  final bool isID;
  final String lastSync;

  const _StatsCard(
      {required this.total, required this.isID, required this.lastSync});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Insets.lg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.people_alt_outlined,
                color: ThemeColor.darkestGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$total ${isID ? 'Petani Terdaftar' : 'Registered Farmers'}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.history, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${isID ? 'Sinkron' : 'Synced'}: $lastSync',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final KthFarmerListController c;
  final bool isID;

  const _SearchBar({required this.c, required this.isID});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c.searchController,
      onChanged: c.onSearchChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: isID
            ? 'Cari nama, no hp, NIK, alamat...'
            : 'Search name, phone, NIK, address...',
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide:
              BorderSide(color: ThemeColor.darkestGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isID ? 'Tidak ada petani ditemukan' : 'No farmers found',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            isID
                ? 'Coba ubah kata kunci pencarian'
                : 'Try a different search term',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
