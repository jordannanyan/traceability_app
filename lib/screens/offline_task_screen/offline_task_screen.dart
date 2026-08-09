import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/api/offline_tasks.dart';
import 'package:traceability_app/screens/offline_task_screen/offline_task_controller.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/app_tokens.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

/// Satu tempat untuk semua pekerjaan yang belum terkirim.
///
/// Sebelumnya antrean offline hanya terlihat di layar asalnya: pohon tertunda
/// baru kelihatan kalau membuka daftar pohon plot itu, plot tertunda kalau
/// membuka lahan petani itu. Di lapangan orang butuh satu jawaban: apa saja
/// yang masih di HP ini, dan berapa yang sudah naik.
class OfflineTaskScreen extends StatelessWidget {
  const OfflineTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => OfflineTaskController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        centerTitle: true,
        title: Obx(
          () => Text(
            c.language.value == 'id' ? 'Data Offline' : 'Offline Data',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: c.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(() {
        final isID = c.language.value == 'id';

        if (c.isLoading.value && c.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final grouped = c.grouped;

        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProgressCard(c: c, isID: isID),
              const SizedBox(height: Insets.lg),

              if (c.pendingCount == 0)
                _AllClear(isID: isID)
              else
                ...grouped.entries.map(
                  (e) => _ModuleSection(
                    c: c,
                    isID: isID,
                    module: e.key,
                    items: e.value,
                  ),
                ),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final isID = c.language.value == 'id';
        final canPress =
            !c.isSyncing.value && !c.isOffline.value && c.syncableCount > 0;

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: canPress ? () => c.syncAll(context) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: ThemeColor.darkestGreen,
            ),
            icon: c.isSyncing.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              c.isSyncing.value
                  ? (isID ? 'Mengunggah...' : 'Uploading...')
                  : c.isOffline.value
                  ? (isID ? 'Menunggu internet' : 'Waiting for internet')
                  : c.syncableCount == 0
                  ? (isID ? 'Tidak ada yang perlu dikirim' : 'Nothing to upload')
                  : (isID
                        ? 'Unggah Semua (${c.syncableCount})'
                        : 'Upload all (${c.syncableCount})'),
            ),
          ),
        );
      }),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final OfflineTaskController c;
  final bool isID;

  const _ProgressCard({required this.c, required this.isID});

  @override
  Widget build(BuildContext context) {
    final percent = c.uploadedPercent;
    final done = c.pendingCount == 0;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isID ? 'Terunggah' : 'Uploaded',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: ThemeColor.darkestGreen,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.isOffline.value)
                const Icon(Icons.wifi_off, color: Colors.brown, size: 20),
            ],
          ),
          const SizedBox(height: Insets.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: c.isSyncing.value ? null : c.uploadedFraction,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.18),
              color: ThemeColor.darkestGreen,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            c.batchTotal > 0
                ? (isID
                      ? '${c.batchDone} dari ${c.batchTotal} data terkirim'
                      : '${c.batchDone} of ${c.batchTotal} uploaded')
                : done
                ? (isID
                      ? 'Semua data sudah terkirim ke server.'
                      : 'Everything has reached the server.')
                : (isID
                      ? '${c.syncableCount} data menunggu diunggah'
                      : '${c.syncableCount} item(s) waiting to upload'),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          if (c.frozenCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              isID
                  ? '${c.frozenCount} data pembelian/penjualan ditahan — menunggu '
                        'menu itu selesai dibangun ulang.'
                  : '${c.frozenCount} purchasing/selling item(s) are held back '
                        'until those menus are rebuilt.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleSection extends StatelessWidget {
  final OfflineTaskController c;
  final bool isID;
  final OfflineModule module;
  final List<OfflineTask> items;

  const _ModuleSection({
    required this.c,
    required this.isID,
    required this.module,
    required this.items,
  });

  IconData get _icon {
    switch (module) {
      case OfflineModule.plot:
        return Icons.terrain_outlined;
      case OfflineModule.tree:
        return Icons.park_outlined;
      case OfflineModule.treeMonitoring:
        return Icons.monitor_heart_outlined;
      case OfflineModule.warehouse:
        return Icons.warehouse_outlined;
      case OfflineModule.farmer:
        return Icons.person_outline;
      case OfflineModule.purchasing:
        return Icons.shopping_bag_outlined;
      case OfflineModule.selling:
        return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: ThemeColor.darkestGreen),
              const SizedBox(width: 8),
              Text(
                module.label(isID),
                style: ThemeTextStyle.textStyleFirstBold.copyWith(fontSize: 15),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ThemeColor.darkestGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.darkestGreen,
                  ),
                ),
              ),
            ],
          ),
          if (!module.canSync)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isID
                    ? 'Ditahan sementara — menu ini sedang dibangun ulang.'
                    : 'Held back — this menu is being rebuilt.',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ),
          const SizedBox(height: Insets.sm),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _TaskRow(c: c, isID: isID, task: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final OfflineTaskController c;
  final bool isID;
  final OfflineTask task;

  const _TaskRow({required this.c, required this.isID, required this.task});

  @override
  Widget build(BuildContext context) {
    final detail = task.detail();

    return Opacity(
      // Yang ditahan tetap terbaca, tapi jelas bukan bagian dari unggahan ini.
      opacity: task.canSync ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail == null
                        ? task.title(isID)
                        : '${task.title(isID)} · $detail',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.fmtQueuedAt(task.queuedAt),
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            PendingSyncBadge(kind: task.kind, isID: isID, compact: true),
          ],
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  final bool isID;

  const _AllClear({required this.isID});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xxl),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_done_outlined,
              size: 40,
              color: ThemeColor.darkestGreen,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            isID ? 'Tidak ada data offline' : 'No offline data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ThemeColor.darkestGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isID
                ? 'Semua catatan lapangan sudah terkirim ke server.'
                : 'Every field record has reached the server.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
