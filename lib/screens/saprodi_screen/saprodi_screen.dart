import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_distributed_saprodi_by_plot_id.dart';
import 'package:traceability_app/screens/saprodi_screen/saprodi_screen_controller.dart';
import 'package:traceability_app/screens/saprodi_screen/saprodi_screen_widget/saprodi_list_widget.dart';
import 'package:traceability_app/screens/saprodi_screen/saprodi_screen_widget/saprodi_mothly_chart.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class SaprodiScreen extends StatelessWidget {
  final int? plotId;
  const SaprodiScreen({super.key, this.plotId});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    int? asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
    final argPlotId = args is Map ? asInt(args['plotId']) : asInt(args);
    final resolvedPlotId = plotId ?? argPlotId;

    final tag = 'saprodi_${resolvedPlotId ?? 0}';
    final c = Get.put(
      SaprodiController(plotId: resolvedPlotId),
      tag: tag,
    );

    return Obx(() {
      final isLoading = c.isLoading.value;
      final errorMsg  = c.error.value;
      final items     = c.items.toList();
      final metric    = c.metric.value;
      final isID      = c.language.value == 'id';
      final empty     = items.isEmpty;

      return Scaffold(
        appBar: AppBar(
          title: Text(isID ? 'Distribusi Saprodi' : 'Saprodi Distribution'),
        ),
        body: _buildBody(
          context: context,
          c: c,
          isLoading: isLoading,
          errorMsg: errorMsg,
          items: items,
          metric: metric,
          isID: isID,
          empty: empty,
        ),
        bottomNavigationBar:
            const BottomNavigationBarWidget(currentIndex: 0),
      );
    });
  }

  Widget _buildBody({
    required BuildContext context,
    required SaprodiController c,
    required bool isLoading,
    required String? errorMsg,
    required List<Datum> items,
    required SaprodiMetric metric,
    required bool isID,
    required bool empty,
  }) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMsg,
                style: ThemeTextStyle
                    .textStyleForthBold
                    .copyWith(color: Colors.red),
                textAlign: TextAlign.center,
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

    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        // Header + metric toggle
        Row(
          children: [
            Expanded(
              child: Text(
                isID
                    ? 'Grafik Saprodi Bulanan'
                    : 'Monthly Saprodi Chart',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SegmentedButton<SaprodiMetric>(
              segments: const [
                ButtonSegment(
                  value: SaprodiMetric.qty,
                  label: Text('Qty'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: SaprodiMetric.net,
                  label: Text('Rp'),
                  icon: Icon(Icons.payments_outlined),
                ),
              ],
              selected: {metric},
              showSelectedIcon: false,
              onSelectionChanged: (s) => c.metric.value = s.first,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Chart / Empty
        if (!empty)
          SaprodiMonthlyChart(
            items: items,
            metric: metric,
            language: c.language.value,
          )
        else
          _EmptyState(
            message: isID
                ? 'Belum ada data saprodi.'
                : 'No saprodi data yet.',
          ),

        const SizedBox(height: 24),

        Text(
          isID ? 'Detail Distribusi' : 'Distribution Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),

        if (!empty)
          SaprodiListWidget(items: items, language: c.language.value)
        else
          _EmptyState(
            message: isID
                ? 'Tidak ada riwayat distribusi.'
                : 'No distribution history.',
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}
