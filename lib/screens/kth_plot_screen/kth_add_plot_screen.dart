import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_add_plot_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_form_card_widget.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen_widget/plot_screen_header_widget.dart';
import 'package:traceability_app/services/language_service.dart';

import 'package:traceability_app/themes/app_tokens.dart';

class KthAddPlotScreen extends StatefulWidget {
  final int farmerId;
  final String? farmerName;
  final String? initialPolygonWkt;
  final PolygonDraft? initialPolygonDraft;

  const KthAddPlotScreen({
    super.key,
    required this.farmerId,
    this.farmerName,
    this.initialPolygonWkt,
    this.initialPolygonDraft,
  });

  @override
  State<KthAddPlotScreen> createState() => _KthAddPlotScreenState();
}

class _KthAddPlotScreenState extends State<KthAddPlotScreen> {
  late final KthAddPlotController c;

  @override
  void initState() {
    super.initState();
    // Create a FRESH controller once per screen mount. Doing this in build()
    // via Get.put returned the *existing* registered instance instead, so the
    // previous farmer's typed data (and their farmerId) stuck around — opening
    // Add Plot for another farmer showed the old, filled form and would even
    // save against the wrong farmer. A GetX-managed Navigator doesn't
    // auto-dispose these, so we force a clean one here on each mount.
    Get.delete<KthAddPlotController>(force: true);
    c = Get.put(
      KthAddPlotController(
        farmerId: widget.farmerId,
        farmerName: widget.farmerName,
        initialPolygonWkt: widget.initialPolygonWkt,
        initialPolygonDraft: widget.initialPolygonDraft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      final farmerTitle = widget.farmerName?.trim();
      final chip = (farmerTitle == null || farmerTitle.isEmpty)
          ? (isID ? 'Petani #${widget.farmerId}' : 'Farmer #${widget.farmerId}')
          : farmerTitle;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(isID ? 'Tambah Plot' : 'Add Plot'),
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
              title: isID ? 'Tambah Plot' : 'Add Plot',
              subtitle: isID
                  ? 'Tambahkan data lahan untuk petani'
                  : 'Add plot data for a farmer',
              chipLabel: chip,
              headerIcon: Icons.add_location_alt_outlined,
              chipIcon: Icons.person_outline,
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
              saveLabel: isID ? 'Simpan' : 'Save',
              polygonButtonLabel:
                  isID ? 'Tambah Polygon dari Map' : 'Add Polygon from Map',
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
