import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/tree_screen/tree_monitoring_controller.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_upsert_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_screen_widget/tree_monitoring_chart_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_screen_widget/tree_monitoring_header_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_screen_widget/tree_monitoring_list_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_screen_widget/tree_monitoring_pagination_bar_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeMonitoringScreen extends StatelessWidget {
  final int treeId;
  const TreeMonitoringScreen({super.key, required this.treeId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      TreeMonitoringController(treeId: treeId),
      tag: 'mon_$treeId',
    );

    return Obx(() {
      final isID = c.language.value == 'id';
      final isOffline = c.isOfflineView.value;
      final syncing = c.syncing.value;
      final isLoading = c.isLoading.value;
      final errorMsg = c.error.value;
      final all = c.all.toList();
      final pageItems = c.pageItems.toList();
      final deleting = c.deleting.toList();
      final page = c.page.value;
      final pageCount = c.pageCount;
      final pageSize = c.pageSize.value;
      final total = c.total;
      final lastSync = c.lastSync.value;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            isID ? 'Riwayat Monitoring' : 'Monitoring History',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
          toolbarHeight: 44,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: c.load,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TreeMonitoringUpsertScreen(treeId: treeId),
              ),
            );
            if (ok == true && context.mounted) {
              await c.load();
            }
          },
          icon: const Icon(Icons.add),
          label: Text(isID ? 'Tambah' : 'Add'),
        ),
        body: FadeTransition(
          opacity: c.fadeAnimation,
          child: _buildBody(
            context: context,
            c: c,
            isID: isID,
            isOffline: isOffline,
            syncing: syncing,
            isLoading: isLoading,
            errorMsg: errorMsg,
            all: all,
            pageItems: pageItems,
            deleting: deleting,
            page: page,
            pageCount: pageCount,
            pageSize: pageSize,
            total: total,
            lastSync: lastSync,
          ),
        ),
      );
    });
  }

  Widget _buildBody({
    required BuildContext context,
    required TreeMonitoringController c,
    required bool isID,
    required bool isOffline,
    required bool syncing,
    required bool isLoading,
    required String? errorMsg,
    required List all,
    required List pageItems,
    required List<int> deleting,
    required int page,
    required int pageCount,
    required int pageSize,
    required int total,
    required DateTime? lastSync,
  }) {
    if (isLoading) {
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

    if (errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMsg,
                textAlign: TextAlign.center,
                style: ThemeTextStyle
                    .textStyleForthBold
                    .copyWith(color: Colors.red, fontSize: 12),
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

    return Column(
      children: [
        if (isOffline)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5CC),
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: const Color(0xFFFFE08A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isID
                        ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                        : 'Offline mode: showing the last saved data.',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed:
                      syncing ? null : () => c.syncNow(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 0),
                    tapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(
                    syncing
                        ? (isID ? 'Menyinkron...' : 'Syncing...')
                        : (isID ? 'Sinkron' : 'Sync'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),

        TreeMonitoringHeader(
          language: c.language.value,
          count: total,
          lastSyncText:
              '${isID ? 'Terakhir sinkron' : 'Last sync'}: ${c.fmtLastSync(lastSync)}',
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: TreeMonitoringMonthlyChart(
            items: c.all.toList(),
            language: c.language.value,
            monthsBack: 6,
            height: 180,
          ),
        ),

        TreeMonitoringPaginationBar(
          isID: isID,
          page: page,
          pageCount: pageCount,
          total: total,
          pageSize: pageSize,
          pageItemsLength: pageItems.length,
          onPrev: page <= 1 ? null : c.goPrev,
          onNext: page >= pageCount ? null : c.goNext,
          onPageSizeChanged: c.setPageSize,
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: TreeMonitoringList(
              items: c.pageItems.toList(),
              language: c.language.value,
              onDelete: (ctx, id) => c.deleteMonitoring(ctx, id),
              deleting: deleting,
              indexOffset: (page - 1) * pageSize,
              pendingKindFor: c.pendingKindFor,
            ),
          ),
        ),
      ],
    );
  }
}
