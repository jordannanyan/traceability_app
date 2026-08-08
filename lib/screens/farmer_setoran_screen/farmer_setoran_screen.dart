import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/farmer_setoran_screen/farmer_setoran_controller.dart';
import 'package:traceability_app/screens/farmer_setoran_screen/setoran_screen_widget/purchasing_list_widget.dart';
import 'package:traceability_app/screens/farmer_setoran_screen/setoran_screen_widget/purchasing_mothly_chart_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class FarmerSetoranScreen extends StatelessWidget {
  const FarmerSetoranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => FarmerSetoranController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
              c.language.value == 'id'
                  ? 'Riwayat Pembelian'
                  : 'Purchase History',
            )),
      ),
      bottomNavigationBar:
          const BottomNavigationBarWidget(currentIndex: 1),
      body: Obx(() {
        final isLoading   = c.isLoading.value;
        final errorMsg    = c.error.value;
        final isOffline   = c.isOfflineView.value;
        final syncing     = c.syncing.value;
        final language    = c.language.value;
        final items       = c.items.toList();
        final metric      = c.metric.value;
        final farmerId    = c.farmerId;

        if (isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (errorMsg != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMsg,
                    style: ThemeTextStyle
                        .textStyleForthBold
                        .copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: c.load,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              // Offline banner
              if (isOffline)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5CC),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border:
                        Border.all(color: const Color(0xFFFFE08A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode offline: menampilkan data terakhir yang tersimpan.',
                          style: ThemeTextStyle.textStyleForthBold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: syncing
                            ? null
                            : () => c.syncNow(context),
                        icon: syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(syncing
                            ? 'Menyinkron...'
                            : 'Sinkron sekarang'),
                      ),
                    ],
                  ),
                ),

              // Chart header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      language == 'id'
                          ? 'Grafik Pembelian Bulanan'
                          : 'Monthly Purchasing Chart',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  SegmentedButton<PurchasingMetric>(
                    segments: const [
                      ButtonSegment(
                        value: PurchasingMetric.kg,
                        label: Text('Kg'),
                        icon: Icon(Icons.scale_outlined),
                      ),
                      ButtonSegment(
                        value: PurchasingMetric.net,
                        label: Text('Rp'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {metric},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        c.metric.value = s.first,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              // Last sync info
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${language == 'id' ? 'Terakhir sinkron' : 'Last sync'}: ${c.fmtLastSync()}',
                      style: ThemeTextStyle
                          .textStyleForthBold
                          .copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              PurchasingMonthlyChart(
                items: items,
                metric: metric,
                language: language,
              ),

              const SizedBox(height: 24),
              Text(
                language == 'id'
                    ? 'Detail Pembelian'
                    : 'Purchasing Details',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (farmerId != null)
                PurchasingListWidget(farmerId: farmerId),

              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}
