import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/get_purchasing_by_kth_id.dart' as kth;
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/services/message_translator.dart';

class EditPurchasingController extends GetxController {
  final kth.Datum? datum;
  EditPurchasingController({this.datum});

  final _api = PurchasingApi();

  final formKey = GlobalKey<FormState>();

  // Text controllers
  final qtyC       = TextEditingController();
  final priceC     = TextEditingController();
  final valueC     = TextEditingController();
  final deductionC = TextEditingController();
  final netC       = TextEditingController();

  // Reactive state
  final saving       = false.obs;
  final isOfflineView = false.obs;
  final autoCalc     = true.obs;
  final date         = DateTime.now().obs;
  final proofValue     = Rxn<File>();
  final proofDeduction = Rxn<File>();
  final proofPayment   = Rxn<File>();

  // Plain fields (set once from datum, never change reactively)
  int? id;
  int? plotId;
  int? warehouseId;
  int? commodityId;
  int? gradeId;
  String plotName      = '-';
  String warehouseName = '-';
  String commodityName = '-';
  String gradeName     = '-';

  StreamSubscription<dynamic>? _connSub;

  @override
  void onInit() {
    super.onInit();
    PurchasingApi.startAutoSyncListener();

    // Populate from datum
    if (datum != null) {
      final d = datum!;
      id          = d.id;
      date.value  = d.date ?? DateTime.now();
      plotId      = d.plotId ?? d.plot?.id;
      warehouseId = d.warehouseId ?? d.warehouse?.id;
      commodityId = d.commoditiesId ?? d.commodity?.id;
      gradeId     = d.gradeId ?? d.grade?.id;
      plotName      = d.plot?.plotName       ?? '-';
      warehouseName = d.warehouse?.warehouseName ?? '-';
      commodityName = d.commodity?.commoditiesName ?? '-';
      gradeName     = d.grade?.gradeName     ?? '-';
      qtyC.text       = _toNumStr(d.quantity);
      priceC.text     = _toNumStr(d.pricePerKg);
      valueC.text     = _toNumStr(d.valuePurchased);
      deductionC.text = _toNumStr(d.deduction);
      netC.text       = _toNumStr(d.netPayment);
    }

    // Auto-calc listeners
    qtyC.addListener(_maybeAutoCalc);
    priceC.addListener(_maybeAutoCalc);
    deductionC.addListener(_maybeAutoCalc);

    _bootConnectivity();
    _connSub = Connectivity().onConnectivityChanged.listen((dynamic conn) {
      isOfflineView.value = !_isOnlineFrom(conn);
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    qtyC.dispose();
    priceC.dispose();
    valueC.dispose();
    deductionC.dispose();
    netC.dispose();
    super.onClose();
  }

  Future<void> _bootConnectivity() async {
    final conn = await Connectivity().checkConnectivity();
    isOfflineView.value = !_isOnlineFrom(conn);
  }

  bool _isOnlineFrom(dynamic conn) {
    try {
      final list = (conn as Iterable).cast<ConnectivityResult>();
      if (list.isEmpty) return false;
      return list.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return conn != ConnectivityResult.none;
    }
  }

  String _toNumStr(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString().trim().replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '.');
  }

  double parseDouble(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0.0;

  void _maybeAutoCalc() {
    if (!autoCalc.value) return;
    final qty       = parseDouble(qtyC.text);
    final price     = parseDouble(priceC.text);
    final deduction = parseDouble(deductionC.text);
    final gross     = qty * price;
    final net       = (gross - deduction).clamp(0, double.infinity);
    valueC.text = gross == 0 ? '' : gross.toStringAsFixed(0);
    netC.text   = net == 0   ? '' : net.toStringAsFixed(0);
    valueC.selection = TextSelection.collapsed(offset: valueC.text.length);
    netC.selection   = TextSelection.collapsed(offset: netC.text.length);
  }

  void toggleAutoCalc(bool v) {
    autoCalc.value = v;
    if (v) _maybeAutoCalc();
  }

  Future<void> pickProof(String which) async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1920, maxHeight: 1920);
    if (x == null) return;
    final f = File(x.path);
    if (which == 'value')     proofValue.value     = f;
    if (which == 'deduction') proofDeduction.value = f;
    if (which == 'payment')   proofPayment.value   = f;
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date.value,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) date.value = picked;
  }

  String fmtDate() => DateFormat('dd MMM yyyy').format(date.value);

  Future<void> save(BuildContext context) async {
    final isID = LanguageService.to.isId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isID
              ? 'ID pembelian tidak ditemukan'
              : 'Purchase ID not found')));
      return;
    }
    if (!formKey.currentState!.validate()) return;

    final pId = plotId      ?? 0;
    final wId = warehouseId ?? 0;
    final cId = commodityId ?? 0;
    final gId = gradeId     ?? 0;

    if (pId == 0 || wId == 0 || cId == 0 || gId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isID
              ? 'Relasi data (plot/gudang/komoditas/grade) tidak lengkap'
              : 'Related data (plot/warehouse/commodity/grade) is incomplete')));
      return;
    }

    saving.value = true;
    try {
      final req = <String, dynamic>{
        'date': DateFormat('yyyy-MM-dd').format(date.value),
        'plot_id': pId,
        'warehouse_id': wId,
        'commodities_id': cId,
        'grade_id': gId,
        'quantity': qtyC.text.trim(),
        'price_per_kg': priceC.text.trim(),
        'value_purchased': valueC.text.trim(),
        'deduction': deductionC.text.trim(),
        'net_payment': netC.text.trim(),
        'upload_proof_value': proofValue.value,
        'upload_proof_deduction': proofDeduction.value,
        'upload_proof_payment': proofPayment.value,
      };

      final res = await _api.editPurchasingOfflineFirst(
          id: id!, requestData: req);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(res.message))));
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      saving.value = false;
    }
  }
}
