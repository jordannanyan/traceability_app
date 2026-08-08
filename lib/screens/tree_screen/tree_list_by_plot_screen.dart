import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/tree_screen/tree_detail_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_list_controller.dart';
import 'package:traceability_app/screens/tree_screen/tree_list_screen_widget/tree_list_queue_bar_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_list_screen_widget/tree_tile_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_upsert_screen.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeListByPlotScreen extends StatelessWidget {
  final int plotId;
  final String plotCode;

  const TreeListByPlotScreen({
    super.key,
    required this.plotId,
    required this.plotCode,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      TreeListController(plotId: plotId, plotCode: plotCode),
      tag: 'list_$plotId',
    );

    return Obx(() {
      final isID = c.language.value == 'id';
      final isOffline = c.isOfflineView.value;
      final syncing = c.syncing.value;
      final loadingRemote = c.loadingRemote.value;
      final outboxTotal = c.outboxTotal.value;
      final syncDone = c.syncDone.value;
      final syncError = c.syncError.value;
      final pageItems = c.pageItems.toList();
      final filtered = c.filtered.toList();
      final page = c.page.value;
      final pageCount = c.pageCount;
      final pageSize = c.pageSize.value;
      final total = c.total;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            plotCode,
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'sync') c.syncOutboxWithProgress(context, silent: false);
                if (v == 'refresh_queue') c.refreshData();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      const Icon(Icons.sync, size: 18),
                      const SizedBox(width: 8),
                      Text(isID ? 'Sinkron Outbox' : 'Sync Outbox'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh_queue',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 18),
                      const SizedBox(width: 8),
                      Text(isID ? 'Refresh Queue' : 'Refresh Queue'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: c.refreshData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (isOffline)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5CC),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: const Color(0xFFFFE08A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isID
                                ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                                : 'Offline mode: showing the last saved data.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: TreeListQueueBar(
                  isID: isID,
                  isOffline: isOffline,
                  syncing: syncing,
                  outboxTotal: outboxTotal,
                  syncDone: syncDone,
                  syncError: syncError,
                  onSync: () =>
                      c.syncOutboxWithProgress(context, silent: false),
                  onRefresh: c.refreshData,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: c.searchC,
                          onChanged: c.onSearchChanged,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: isID
                                ? 'Cari nama/jenis/QR/ID pohon...'
                                : 'Search name/species/QR/ID...',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () => c.scanQr(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: isID ? 'Scan QR' : 'Scan QR',
                      ),
                    ],
                  ),
                ),
              ),

              if (loadingRemote)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Text(
                    isID ? 'Daftar Pohon' : 'Tree List',
                    style: ThemeTextStyle.textStyleFirstBold,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _paginationBar(
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
              ),

              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: _cardDeco(),
                    child: Center(
                      child: Text(
                        isID
                            ? 'Tidak ada pohon yang cocok'
                            : 'No matching trees',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: _cardDeco(),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = pageItems[i];
                          final globalIndex =
                              ((page - 1) * pageSize) + i + 1;

                          return Dismissible(
                            key: ValueKey(
                                'tree_${item.id ?? globalIndex}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async =>
                                await c.handleDelete(ctx, item),
                            background: Container(
                              color: Colors.red.shade50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    isID ? 'Hapus' : 'Delete',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: TreeTile(
                              data: item,
                              index: globalIndex,
                              pendingKind: c.pendingKindFor(item.id),
                              isID: isID,
                              onTap: () async {
                                final id = item.id;
                                if (id == null) return;
                                // Queued rows have no server record to open.
                                if (c.isRowLocked(id)) {
                                  showPendingRowMessage(ctx, isID: isID);
                                  return;
                                }
                                await Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TreeDetailScreen(treeId: id),
                                  ),
                                );
                                if (ctx.mounted) await c.refreshData();
                              },
                              onDelete: () async =>
                                  await c.handleDelete(ctx, item),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => TreeUpsertScreen(plotId: plotId),
              ),
            );
            if (ok == true && context.mounted) {
              await c.refreshData();
            }
          },
          icon: const Icon(Icons.add),
          label: Text(isID ? 'Tambah Pohon' : 'Add Tree'),
        ),
      );
    });
  }

  Widget _paginationBar({
    required bool isID,
    required int page,
    required int pageCount,
    required int total,
    required int pageSize,
    required int pageItemsLength,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
    required void Function(int) onPageSizeChanged,
  }) {
    final start = total == 0 ? 0 : ((page - 1) * pageSize + 1);
    final end = total == 0 ? 0 : ((page - 1) * pageSize + pageItemsLength);

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDeco(),
      child: Row(
        children: [
          IconButton(
            tooltip: isID ? 'Sebelumnya' : 'Previous',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${isID ? "Halaman" : "Page"} $page/$pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isID ? "Menampilkan" : "Showing"} $start-$end ${isID ? "dari" : "of"} $total',
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isID ? 'Berikutnya' : 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: pageSize,
            underline: const SizedBox.shrink(),
            onChanged: (v) {
              if (v == null) return;
              onPageSizeChanged(v);
            },
            items: const [10, 20, 30, 50, 100]
                .map((e) =>
                    DropdownMenuItem<int>(value: e, child: Text('$e')))
                .toList(),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
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
      );
}
