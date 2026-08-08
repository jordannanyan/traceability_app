import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_edit_plot_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_form_card_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_screen_header_widget.dart';
import 'package:traceability_app/services/language_service.dart';

import 'package:traceability_app/themes/app_tokens.dart';

class KthEditPlotScreen extends StatefulWidget {
  const KthEditPlotScreen({super.key});

  @override
  State<KthEditPlotScreen> createState() => _KthEditPlotScreenState();
}

class _KthEditPlotScreenState extends State<KthEditPlotScreen> {
  late final KthEditPlotController c;
  bool _argsApplied = false;

  @override
  void initState() {
    super.initState();
    // Create a fresh controller ONCE per screen mount. Doing this in build()
    // (the previous approach) meant every rebuild — e.g. the keyboard/MediaQuery
    // change when the GPS dialog opens — recreated the controller and re-ran
    // initFromArgs, wiping runtime-set fields like the just-captured coordinates
    // back to the original plot values. Standard Navigator doesn't auto-dispose
    // GetX controllers, so we force a fresh one here on each mount.
    Get.delete<KthEditPlotController>(force: true);
    c = Get.put(KthEditPlotController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute args are available here (not safely in initState). Apply once.
    if (!_argsApplied) {
      _argsApplied = true;
      c.initFromArgs(ModalRoute.of(context)?.settings.arguments);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(isID ? 'Edit Plot' : 'Edit Plot'),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            PlotScreenHeader(
              title: isID ? 'Edit Plot' : 'Edit Plot',
              subtitle: isID ? 'Perbarui data lahan' : 'Update plot data',
              chipLabel: c.nameCtrl.text.trim().isEmpty
                  ? (isID ? 'Edit Plot' : 'Edit Plot')
                  : c.nameCtrl.text.trim(),
              headerIcon: Icons.map_outlined,
              chipIcon: Icons.agriculture,
            ),
            const SizedBox(height: 16),
            PlotFormCard(
              formKey: c.formKey,
              nameCtrl: c.nameCtrl,
              landAreaCtrl: c.landAreaCtrl,
              plantsCtrl: c.plantsCtrl,
              latCtrl: c.latCtrl,
              lngCtrl: c.lngCtrl,
              polygonCtrl: c.polygonCtrl,
              isSaving: c.isSaving,
              saveLabel: isID ? 'Simpan Perubahan' : 'Save Changes',
              polygonButtonLabel:
                  isID ? 'Edit Polygon dari Map' : 'Edit Polygon from Map',
              onSave: () => c.save(context),
              onCancel: () => Navigator.pop(context, false),
              onOpenPolygonEditor: () => c.goPolygonEditor(context),
              onGetCoordinates: () => c.getCoordinates(context),
            ),
          ],
        ),
      );
    });
  }
}
