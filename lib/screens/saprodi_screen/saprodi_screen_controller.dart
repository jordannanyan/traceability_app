import 'package:get/get.dart';

import 'package:traceability_app/models/api/distributed_saprodi_api.dart';
import 'package:traceability_app/models/get_distributed_saprodi_by_plot_id.dart';
import 'package:traceability_app/screens/saprodi_screen/saprodi_screen_widget/saprodi_mothly_chart.dart';
import 'package:traceability_app/services/language_service.dart';

class SaprodiController extends GetxController {
  final int? plotId;
  SaprodiController({this.plotId});

  final language  = LanguageService.to.language;
  final isLoading = false.obs;
  final error     = RxnString();
  final items     = <Datum>[].obs;
  final metric    = SaprodiMetric.net.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      if (plotId == null || plotId == 0) {
        items.value = [];
        return;
      }

      final api = DistributedSaprodiApi();
      final res = await api.getDistributedSaprodiByPlotId(plotId!);
      final loaded = (res.data ?? <Datum>[])
          .where((d) => d.date != null)
          .toList()
        ..sort((a, b) => a.date!.compareTo(b.date!));
      items.value = loaded;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
