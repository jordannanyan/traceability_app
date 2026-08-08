import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/purchasing_screen/purchasing_controller.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen_widget/purchasing_bar_chart_widget.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen_widget/purchasing_card_widget.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen_widget/purchasing_header_widget.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen_widget/purchasing_offline_banner_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/button_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
// Kept for backwards-compatibility if registered in MaterialApp.
// No longer used by PurchasingScreen internally.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class PurchasingScreen extends StatelessWidget {
  const PurchasingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => PurchasingController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(
              c.language.value == 'id' ? 'Pembelian' : 'Purchasing',
              style: ThemeTextStyle.textStyleFirstBoldWhite,
            )),
      ),
      body: Obx(() {
        final isLoading = c.isLoading.value;
        final errorMsg = c.error.value;
        final isID = c.language.value == 'id';
        final data = c.data.value;
        final list = data?.data ?? const [];
        final isOfflineView = c.isOfflineView.value;
        final isSyncing = c.isSyncing.value;
        final lastSync = c.lastSync.value;

        if (isLoading && data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (errorMsg != null && data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMsg,
                    textAlign: TextAlign.center,
                    style: ThemeTextStyle
                        .textStyleForthBold
                        .copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: c.load,
                    child: Text(isID ? 'Coba Lagi' : 'Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: c.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOfflineView)
                    PurchasingOfflineBanner(
                      isID: isID,
                      isSyncing: isSyncing,
                      onSync: () => c.syncNow(context),
                    ),

                  PurchasingHeader(
                    isID: isID,
                    lastSyncText:
                        '${isID ? 'Terakhir sinkron' : 'Last sync'}: ${c.fmtLastSync(lastSync)}',
                  ),
                  const SizedBox(height: 8),

                  // Chart card
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.10),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: list.isNotEmpty && data != null
                        ? PurchasingBarChart(
                            data,
                            language: isID ? 'id' : 'en',
                          )
                        : Center(
                            child: Text(
                              isID
                                  ? 'Tidak ada data pembelian tersedia'
                                  : 'No purchasing data available',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isID ? 'Riwayat Pembelian' : 'Purchasing History',
                    style: ThemeTextStyle.textStyleFirstBold,
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ButtonWidget(
                      textButton:
                          isID ? 'Tambah Pembelian' : 'Add Purchasing',
                      route: '',
                      onPressed: isOfflineView
                          ? null
                          : () async {
                              final added = await Navigator.pushNamed(
                                context,
                                '/add-Pembelian',
                              );
                              if (added == true) {
                                await c.load();
                              }
                            },
                    ),
                  ),

                  if (list.isNotEmpty && data != null)
                    PurchasingCardWidget(
                      purchasingData: data,
                      language: isID ? 'id' : 'en',
                      isOffline: isOfflineView,
                      onEdited: c.load,
                      pendingKindFor: c.pendingKindFor,
                    )
                  else
                    Center(
                      child: Text(
                        isID
                            ? 'Tidak ada riwayat Pembelian tersedia'
                            : 'No Purchasing history available',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 1),
    );
  }
}
