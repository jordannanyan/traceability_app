import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:traceability_app/screens/home_kth_screen/home_kth_controller.dart';
import 'package:traceability_app/screens/home_kth_screen/home_kth_screen_widget/gudang_card_widget.dart';
import 'package:traceability_app/screens/home_kth_screen/home_kth_screen_widget/penjualan_card_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_farmer_list_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_screen.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/home_green_header.dart';
import 'package:traceability_app/screens/widgets/section_header.dart';
import 'package:traceability_app/utils/controller_registry.dart';

class HomeKthScreen extends StatelessWidget {
  const HomeKthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => HomeKthController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Obx(
              () => HomeGreenHeader(
                isID: c.language.value == 'id',
                name: c.kthName.value,
                nameFallback: c.language.value == 'id' ? 'Partner' : 'Partner',
                isOffline: c.isOffline.value,
                lastSync: c.lastSyncDisplay.value,
                quickActions: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      QuickActionTile(
                        icon: Icons.people_alt_outlined,
                        label: c.language.value == 'id' ? 'Petani' : 'Farmers',
                        trailingSpace: 20,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KthFarmerListScreen(),
                          ),
                        ),
                      ),
                      QuickActionTile(
                        icon: Icons.warehouse_outlined,
                        label: c.language.value == 'id' ? 'Gudang' : 'Warehouse',
                        trailingSpace: 20,
                        onTap: () => Navigator.pushNamed(context, '/gudang'),
                      ),
                      QuickActionTile(
                        icon: Icons.park_outlined,
                        label: c.language.value == 'id' ? 'Pohon' : 'Trees',
                        trailingSpace: 20,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TreeScreen()),
                        ),
                      ),
                      QuickActionTile(
                        icon: Icons.sell_outlined,
                        label: c.language.value == 'id' ? 'Penjualan' : 'Sales',
                        trailingSpace: 20,
                        onTap: () => Navigator.pushNamed(context, '/penjualan'),
                      ),
                      QuickActionTile(
                        icon: Icons.receipt_long_outlined,
                        label: c.language.value == 'id'
                            ? 'Pembelian'
                            : 'Purchasing',
                        onTap: () => Navigator.pushNamed(context, '/setoran'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: c.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Obx(
                      () => SectionHeader(
                        title: c.language.value == 'id' ? 'Gudang' : 'Warehouse',
                        viewMoreLabel: c.language.value == 'id'
                            ? 'Lihat Semua'
                            : 'View All',
                        onTap: () => Navigator.pushNamed(context, '/gudang'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GudangSection(c: c),
                    const SizedBox(height: 20),
                    Obx(
                      () => SectionHeader(
                        title: c.language.value == 'id' ? 'Penjualan' : 'Sales',
                        viewMoreLabel: c.language.value == 'id'
                            ? 'Lihat Semua'
                            : 'View All',
                        onTap: () => Navigator.pushNamed(context, '/penjualan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PenjualanSection(c: c),
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

class _GudangSection extends StatelessWidget {
  final HomeKthController c;
  const _GudangSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final d = c.warehouseData.value;
      if (d != null && (d.data ?? []).isNotEmpty) {
        return GudangCardRowWithData(
          gudangData: d,
          language: c.language.value,
          isOffline: c.isOffline.value,
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            c.language.value == 'id'
                ? 'Tidak ada data gudang tersedia'
                : 'No warehouse data available',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    });
  }
}

class _PenjualanSection extends StatelessWidget {
  final HomeKthController c;
  const _PenjualanSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final d = c.sellingData.value;
      if (d != null && (d.data ?? []).isNotEmpty) {
        return PenjualanCardColumn(
          penjualanData: d,
          language: c.language.value,
          isOffline: c.isOffline.value,
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            c.language.value == 'id'
                ? 'Tidak ada data penjualan tersedia'
                : 'No sales data available',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    });
  }
}
