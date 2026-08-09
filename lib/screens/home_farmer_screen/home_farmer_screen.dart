import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:traceability_app/screens/home_farmer_screen/home_farmer_controller.dart';
import 'package:traceability_app/screens/home_farmer_screen/home_farmer_screen_widget/plot_list_farmer_widget.dart';
import 'package:traceability_app/screens/widgets/under_development.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/home_green_header.dart';
import 'package:traceability_app/screens/widgets/section_header.dart';
import 'package:traceability_app/utils/controller_registry.dart';

class HomeFarmerScreen extends StatelessWidget {
  const HomeFarmerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => HomeFarmerController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Obx(() => HomeGreenHeader(
                  isID: c.language.value == 'id',
                  name: c.farmerName.value,
                  nameFallback:
                      c.language.value == 'id' ? 'Petani' : 'Farmer',
                  isOffline: c.isOfflineView.value,
                  lastSync: '-',
                  quickActions: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      QuickActionTile(
                        icon: Icons.terrain_outlined,
                        label: c.language.value == 'id' ? 'Lahan' : 'Land',
                        onTap: () => Navigator.pushNamed(context, '/lahan'),
                      ),
                      QuickActionTile(
                        icon: Icons.receipt_long_outlined,
                        label: c.language.value == 'id'
                            ? 'Setoran'
                            : 'Deposits',
                        onTap: () => Navigator.pushNamed(
                            context, '/pembelian-petani'),
                      ),
                      QuickActionTile(
                        icon: Icons.cloud_upload_outlined,
                        label: c.language.value == 'id'
                            ? 'Data Offline'
                            : 'Offline Data',
                        onTap: () =>
                            Navigator.pushNamed(context, '/data-offline'),
                      ),
                      QuickActionTile(
                        icon: Icons.settings_outlined,
                        label: c.language.value == 'id'
                            ? 'Pengaturan'
                            : 'Settings',
                        onTap: () => Navigator.pushNamed(
                            context, '/settings-farmer'),
                      ),
                    ],
                  ),
                )),
            Expanded(
              child: RefreshIndicator(
                onRefresh: c.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Obx(() => SectionHeader(
                          title: c.language.value == 'id' ? 'Lahan' : 'Plots',
                          viewMoreLabel: c.language.value == 'id'
                              ? 'Lihat Semua'
                              : 'View All',
                          onTap: () => Navigator.pushNamed(context, '/lahan'),
                        )),
                    const SizedBox(height: 8),
                    PlotListFarmerWidget(
                      onViewSaprodi: (i, item) =>
                          Navigator.pushNamed(context, '/saprodi'),
                      onEditPlot: (i, item) => Navigator.pushNamed(
                          context, '/edit_plot',
                          arguments: item),
                      onTapPlot: (i, item) {},
                    ),
                    const SizedBox(height: 20),
                    Obx(() => SectionHeader(
                          title: c.language.value == 'id'
                              ? 'Setoran'
                              : 'Deposits',
                          viewMoreLabel: c.language.value == 'id'
                              ? 'Lihat Semua'
                              : 'View All',
                          onTap: () => Navigator.pushNamed(
                              context, '/pembelian-petani'),
                        )),
                    const SizedBox(height: 8),
                    // Setoran mengikuti struktur data baru dan endpoint lamanya
                    // sudah tidak ada — jangan tampilkan angka lama dari cache.
                    Obx(
                      () => UnderDevelopmentCard(
                        isID: c.language.value == 'id',
                        featureName: c.language.value == 'id'
                            ? 'Setoran'
                            : 'Deposits',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 0),
    );
  }
}
