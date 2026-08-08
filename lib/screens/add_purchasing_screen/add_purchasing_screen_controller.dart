import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/commodities_api.dart';
import 'package:traceability_app/models/api/grade_api.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/api/warehouse_api.dart';
import 'package:traceability_app/services/language_service.dart';

class AddPurchasingController extends GetxController {
  // Auth / language
  final language = LanguageService.to.language;
  int kthId = 0;

  // Dropdowns selections
  final selectedGudangId = Rxn<int>();
  final selectedPlotId = Rxn<int>();
  final selectedCoffeeId = Rxn<int>();
  final selectedGradeId = Rxn<int>();

  // Dropdown sources
  final plots = [].obs;
  final warehouses = [].obs;
  final commodities = [].obs;
  final grades = [].obs;

  // Text controllers
  final quantityC = TextEditingController();
  final pricePerKgC = TextEditingController();
  final valuePurchasedC = TextEditingController();
  final deductionC = TextEditingController();
  final netPaymentC = TextEditingController();
  final dateC = TextEditingController();

  // Field errors
  final gudangError = ''.obs;
  final plotError = ''.obs;
  final coffeeError = ''.obs;
  final gradeError = ''.obs;
  final quantityError = ''.obs;
  final pricePerKgError = ''.obs;
  final valuePurchasedError = ''.obs;
  final deductionError = ''.obs;
  final netPaymentError = ''.obs;
  final dateError = ''.obs;

  // Images
  final proofValueImage = Rxn<File>();
  final proofDeductionImage = Rxn<File>();
  final proofPaymentImage = Rxn<File>();

  // UI state
  final loadingSources = true.obs;
  final saving = false.obs;

  final _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    quantityC.addListener(_calcGross);
    pricePerKgC.addListener(_calcGross);
    valuePurchasedC.addListener(_calcNet);
    deductionC.addListener(_calcNet);
    _boot();
  }

  @override
  void onClose() {
    quantityC.dispose();
    pricePerKgC.dispose();
    valuePurchasedC.dispose();
    deductionC.dispose();
    netPaymentC.dispose();
    dateC.dispose();
    super.onClose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    kthId = prefs.getInt('kth_id') ??
        prefs.getInt('kthId') ??
        prefs.getInt('id') ??
        0;
    await _loadSources();
    loadingSources.value = false;
  }

  Future<void> _loadSources() async {
    try {
      final plotRes = await PlotApi().getPlotByKthId(kthId);
      final whRes = await WarehouseApi().getWarehouseByKthId(kthId);
      final comRes = await CommoditiesApi().getCommodities();
      final grdRes = await GradeApi().getGrades();

      plots.value = _extractList(plotRes);
      warehouses.value = _extractList(whRes);
      commodities.value = _extractList(comRes);
      grades.value = _extractList(grdRes);
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data awal: $e');
    }
  }

  List<dynamic> _extractList(dynamic res) {
    try {
      if (res is List) return res;
      final data = (res as dynamic).data;
      if (data is List) return data;
    } catch (_) {}
    try {
      final g = (res as dynamic).grades;
      if (g is List) return g;
    } catch (_) {}
    return const [];
  }

  void _calcGross() {
    final q = double.tryParse(quantityC.text.replaceAll(',', '.')) ?? 0.0;
    final p = double.tryParse(pricePerKgC.text.replaceAll(',', '.')) ?? 0.0;
    final gross = q * p;
    valuePurchasedC.text = gross == 0 ? '' : gross.toStringAsFixed(0);
    _calcNet();
  }

  void _calcNet() {
    final gross =
        double.tryParse(valuePurchasedC.text.replaceAll(',', '.')) ?? 0.0;
    final deduction =
        double.tryParse(deductionC.text.replaceAll(',', '.')) ?? 0.0;
    final net = (gross - deduction).clamp(0, double.infinity);
    netPaymentC.text = net == 0 ? '' : net.toStringAsFixed(0);
  }

  Future<void> pickImage(String which) async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1920, maxHeight: 1920);
    if (f == null) return;
    final file = File(f.path);
    if (which == 'value') proofValueImage.value = file;
    if (which == 'deduction') proofDeductionImage.value = file;
    if (which == 'payment') proofPaymentImage.value = file;
  }

  Future<void> selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    dateC.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    dateError.value = '';
  }

  bool validate() {
    final isID = language.value == 'id';
    bool ok = true;

    if (selectedGudangId.value == null) {
      gudangError.value =
          isID ? 'Gudang harus dipilih' : 'Warehouse must be selected';
      ok = false;
    } else {
      gudangError.value = '';
    }

    if (selectedPlotId.value == null) {
      plotError.value =
          isID ? 'Plot harus dipilih' : 'Plot must be selected';
      ok = false;
    } else {
      plotError.value = '';
    }

    if (selectedCoffeeId.value == null) {
      coffeeError.value =
          isID ? 'Komoditas harus dipilih' : 'Commodity must be selected';
      ok = false;
    } else {
      coffeeError.value = '';
    }

    if (selectedGradeId.value == null) {
      gradeError.value =
          isID ? 'Grade harus dipilih' : 'Grade must be selected';
      ok = false;
    } else {
      gradeError.value = '';
    }

    String numErr(String idLabel, String enLabel, TextEditingController c) {
      if (c.text.isEmpty) {
        return isID
            ? '$idLabel tidak boleh kosong'
            : '$enLabel cannot be empty';
      }
      if (double.tryParse(c.text.replaceAll(',', '.')) == null) {
        return isID
            ? '$idLabel harus berupa angka'
            : '$enLabel must be a number';
      }
      return '';
    }

    quantityError.value = numErr('Kuantitas', 'Quantity', quantityC);
    pricePerKgError.value = numErr('Harga per kg', 'Price per kg', pricePerKgC);
    valuePurchasedError.value =
        numErr('Nilai pembelian', 'Purchase value', valuePurchasedC);
    deductionError.value = numErr('Potongan', 'Deduction', deductionC);
    netPaymentError.value = '';

    if (dateC.text.isEmpty) {
      dateError.value =
          isID ? 'Tanggal tidak boleh kosong' : 'Date cannot be empty';
      ok = false;
    } else {
      dateError.value = '';
    }

    return ok &&
        quantityError.value.isEmpty &&
        pricePerKgError.value.isEmpty &&
        valuePurchasedError.value.isEmpty &&
        deductionError.value.isEmpty;
  }

  void _resetForm() {
    selectedGudangId.value = null;
    selectedPlotId.value = null;
    selectedCoffeeId.value = null;
    selectedGradeId.value = null;
    quantityC.clear();
    pricePerKgC.clear();
    valuePurchasedC.clear();
    deductionC.clear();
    netPaymentC.clear();
    dateC.clear();
    proofValueImage.value = null;
    proofDeductionImage.value = null;
    proofPaymentImage.value = null;
    gudangError.value = '';
    plotError.value = '';
    coffeeError.value = '';
    gradeError.value = '';
    quantityError.value = '';
    pricePerKgError.value = '';
    valuePurchasedError.value = '';
    deductionError.value = '';
    netPaymentError.value = '';
    dateError.value = '';
  }

  Future<void> save(BuildContext context) async {
    if (!validate()) return;
    if (saving.value) return;
    saving.value = true;
    try {
      final body = {
        'date': dateC.text,
        'plot_id': selectedPlotId.value,
        'warehouse_id': selectedGudangId.value,
        'commodities_id': selectedCoffeeId.value,
        'quantity': quantityC.text,
        'grade_id': selectedGradeId.value,
        'price_per_kg': pricePerKgC.text,
        'value_purchased': valuePurchasedC.text,
        'deduction': deductionC.text,
        'net_payment': netPaymentC.text,
        'upload_proof_value': proofValueImage.value,
        'upload_proof_deduction': proofDeductionImage.value,
        'upload_proof_payment': proofPaymentImage.value,
      };

      await PurchasingApi().addPurchasing(body);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(language.value == 'id'
            ? 'Pembelian berhasil ditambahkan!'
            : 'Purchase added successfully!'),
      ));
      _resetForm();
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
