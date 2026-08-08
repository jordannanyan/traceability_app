import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/selling_screen/selling_controller.dart';
import 'package:traceability_app/screens/selling_screen/selling_screen_widget/selling_chart_widget.dart';
import 'package:traceability_app/screens/selling_screen/selling_screen_widget/selling_header_section_widget.dart';
import 'package:traceability_app/screens/selling_screen/selling_screen_widget/selling_list_widget.dart';
import 'package:traceability_app/screens/selling_screen/selling_screen_widget/selling_offline_banner_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SellingScreen extends StatelessWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => SellingController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(
              c.language.value == 'id' ? 'Penjualan' : 'Selling',
              style: ThemeTextStyle.textStyleFirstBoldWhite,
            )),
        toolbarHeight: 44,
      ),
      body: Obx(() {
        final isLoading = c.isLoading.value;
        final errorMsg = c.error.value;
        final isID = c.language.value == 'id';
        final items = c.items.toList();
        final isOfflineView = c.isOfflineView.value;
        final isSyncing = c.isSyncing.value;
        final lastSync = c.lastSync.value;

        if (isLoading && items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.lg),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (errorMsg != null && items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMsg,
                    textAlign: TextAlign.center,
                    style: ThemeTextStyle.textStyleForthBold.copyWith(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: c.load,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: Text(
                      isID ? 'Coba Lagi' : 'Try Again',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FadeTransition(
          opacity: c.fadeAnimation,
          child: Column(
            children: [
              if (isOfflineView)
                SellingOfflineBanner(
                  isID: isID,
                  isSyncing: isSyncing,
                  onSync: () => c.syncNow(context),
                ),
              const SizedBox(height: 6),
              SellingHeaderSection(
                isID: isID,
                count: items.length,
                lastSyncText:
                    '${isID ? 'Terakhir sinkron' : 'Last sync'}: ${c.fmtLastSync(lastSync)}',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: SellingMonthlyChart(
                  items: items,
                  language: isID ? 'id' : 'en',
                  monthsBack: 6,
                  height: 180,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: c.load,
                  child: SellingList(
                    items: items,
                    language: isID ? 'id' : 'en',
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 0),
    );
  }
}
