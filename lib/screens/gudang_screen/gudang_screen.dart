import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/screens/gudang_screen/gudang_controller.dart';
import 'package:traceability_app/screens/gudang_screen/gudang_screen_widget/gudang_card_widget.dart';
import 'package:traceability_app/screens/gudang_screen/gudang_screen_widget/gudang_detail_sheet_widget.dart';
import 'package:traceability_app/screens/gudang_screen/gudang_screen_widget/gudang_header_section_widget.dart';
import 'package:traceability_app/screens/gudang_screen/gudang_screen_widget/gudang_offline_banner_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class GudangScreen extends StatelessWidget {
  const GudangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => GudangController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Obx(() => Text(
              c.language.value == 'id' ? 'Daftar Gudang' : 'Warehouses',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 0.5),
            )),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ThemeColor.darkestGreen,
                ThemeColor.darkestGreen.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Obx(() {
        final isLoading = c.isLoading.value;
        final error = c.error.value;
        final itemCount = c.items.length;

        if (isLoading && itemCount == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (error != null && itemCount == 0) {
          final isID = c.language.value == 'id';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error,
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

        // Read all reactive values in the Obx scope.
        final isID = c.language.value == 'id';
        final items = c.items.toList();
        final lastSync = c.fmtLastSync(c.lastSync.value);
        final isOfflineView = c.isOfflineView.value;
        final isSyncing = c.isSyncing.value;

        return FadeTransition(
          opacity: c.fadeAnimation,
          child: Column(
            children: [
              if (isOfflineView)
                GudangOfflineBanner(
                  isID: isID,
                  isSyncing: isSyncing,
                  onSync: () => c.syncNow(context),
                ),
              const SizedBox(height: 8),
              GudangHeaderSection(
                isID: isID,
                count: items.length,
                lastSync: lastSync,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: c.load,
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.xl),
                            child: Text(
                              isID
                                  ? 'Belum ada gudang.'
                                  : 'No warehouses yet.',
                              style: ThemeTextStyle
                                  .textStyleForthBold
                                  .copyWith(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return TweenAnimationBuilder<double>(
                              duration:
                                  Duration(milliseconds: 280 + (index * 90)),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: GudangCard(
                                      item: item,
                                      isID: isID,
                                      pendingKind: c.pendingKindFor(item.id),
                                      onTap: () =>
                                          _showDetail(context, item, isID, c),
                                      onEdit: () async {
                                        final changed =
                                            await Navigator.pushNamed(
                                          context,
                                          '/edit_warehouse',
                                          arguments: item,
                                        );
                                        if (changed == true) c.load();
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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

  void _showDetail(
    BuildContext context,
    wh.Datum item,
    bool isID,
    GudangController c,
  ) {
    final createdAt =
        item.createdAt != null ? c.fmtDate(item.createdAt!) : '-';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GudangDetailSheet(
        item: item,
        isID: isID,
        createdAt: createdAt,
      ),
    );
  }
}
