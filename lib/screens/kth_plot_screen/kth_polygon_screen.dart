import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/polygon_bottom_action_bar_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/polygon_map_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/polygon_top_info_bar_widget.dart';
import 'package:traceability_app/services/language_service.dart';

class KthPolygonScreen extends StatefulWidget {
  const KthPolygonScreen({super.key});

  @override
  State<KthPolygonScreen> createState() => _KthPolygonScreenState();
}

class _KthPolygonScreenState extends State<KthPolygonScreen> {
  late final KthPolygonController c;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (Get.isRegistered<KthPolygonController>()) {
      Get.delete<KthPolygonController>(force: true);
    }
    c = Get.put(KthPolygonController());
    c.initFromArgs(args);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await c.confirmLeave(context);
        if (context.mounted && ok) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Obx(() => Text(
              LanguageService.to.language.value == 'id'
                  ? 'Edit Polygon'
                  : 'Edit Polygon')),
          actions: [
            IconButton(
              tooltip: 'Copy WKT',
              onPressed: () => c.copyWkt(context),
              icon: const Icon(Icons.copy),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            PolygonTopInfoBar(c: c, ctx: context),
            Expanded(child: KthPolygonMapWidget(c: c)),
            PolygonBottomActionBar(c: c, ctx: context),
          ],
        ),
      ),
    );
  }
}
