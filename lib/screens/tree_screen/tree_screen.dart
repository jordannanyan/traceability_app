import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/tree_screen/tree_list_by_plot_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_screen_controller.dart';
import 'package:traceability_app/screens/tree_screen/tree_screen_widget/tree_farmer_card_widget.dart';
import 'package:traceability_app/screens/tree_screen/tree_screen_widget/tree_offline_banner_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeScreen extends StatelessWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => TreeController());

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(
              c.language.value == 'id' ? 'Data Pohon' : 'Trees',
              style: ThemeTextStyle.textStyleFirstBoldWhite,
            )),
      ),
      body: Obx(() {
        final isID = c.language.value == 'id';
        final isOfflineView = c.isOfflineView.value;
        final isSyncing = c.syncing.value;
        final loadingFarmers = c.loadingFarmers.value;
        final loadingRemote = c.loadingRemote.value;
        final farmers = c.farmers.toList();
        final plotsByFarmer = Map<int, List<PlotLite>>.from(c.plotsByFarmer);
        final expanded = Map<int, bool>.from(c.expanded);
        final searchText = c.searchText.value;

        return RefreshIndicator(
          onRefresh: () => c.loadFarmers(
            search: c.searchC.text.trim().isEmpty
                ? null
                : c.searchC.text.trim(),
          ),
          child: ListView(
            children: [
              if (isOfflineView)
                TreeOfflineBanner(
                  isID: isID,
                  isSyncing: isSyncing,
                  onSync: () => c.syncNow(context),
                ),

              // Header + Search
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeColor
                            .darkestGreen
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.people_alt_outlined,
                        color: ThemeColor.darkestGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isID ? 'Daftar Petani' : 'Farmers',
                        style: ThemeTextStyle.textStyleFirstBold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: TextField(
                  controller: c.searchC,
                  onChanged: c.onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              c.searchC.clear();
                              c.onSearchChanged('');
                            },
                          )
                        : null,
                    hintText: isID
                        ? 'Cari nama petani...'
                        : 'Search farmer name...',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),

              if (loadingRemote)
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),

              if (loadingFarmers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (farmers.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 24),
                  decoration: _cardDeco(),
                  child: Center(
                    child: Text(
                      isID
                          ? 'Tidak ada petani yang cocok.'
                          : 'No matching farmers.',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    children: [
                      for (final f in farmers)
                        Container(
                          margin:
                              const EdgeInsets.only(bottom: 12),
                          decoration: _cardDeco(),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: PageStorageKey(
                                  'farmer_${f.id}'),
                              initiallyExpanded:
                                  expanded[f.id] ?? false,
                              collapsedShape:
                                  RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              12)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(Radii.md)),
                              tilePadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(
                                      6, 0, 6, 10),
                              title: Row(
                                children: [
                                  TreeAvatarInitials(
                                      name: f.name),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          f.name,
                                          style:
                                              Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                        ),
                                        const SizedBox(height: 2),
                                        if ((f.kthName
                                                ?.isNotEmpty ??
                                            false))
                                          Text(
                                            'KTH: ${f.kthName}',
                                            style:
                                                const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors
                                                        .black54),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TreePlotCountPill(
                                    count: plotsByFarmer[f.id]
                                        ?.length,
                                  ),
                                ],
                              ),
                              onExpansionChanged: (open) {
                                c.toggleExpanded(f.id, open);
                              },
                              children: [
                                if (!plotsByFarmer
                                    .containsKey(f.id))
                                  const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                            6, 0, 6, 10),
                                    child: Column(
                                      children: [
                                        for (int i = 0;
                                            i <
                                                plotsByFarmer[
                                                        f.id]!
                                                    .length;
                                            i++) ...[
                                          TreePlotListTile(
                                            plot: plotsByFarmer[
                                                f.id]![i],
                                            isID: isID,
                                            onTap: () async {
                                              final p =
                                                  plotsByFarmer[
                                                      f.id]![i];
                                              await Navigator
                                                  .push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TreeListByPlotScreen(
                                                    plotId: p.id,
                                                    plotCode:
                                                        p.code,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          if (i !=
                                              plotsByFarmer[
                                                          f.id]!
                                                      .length -
                                                  1)
                                            const Divider(
                                                height: 1),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      }),
      bottomNavigationBar:
          const BottomNavigationBarWidget(currentIndex: 0),
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
