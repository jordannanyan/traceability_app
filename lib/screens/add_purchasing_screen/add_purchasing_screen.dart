import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/add_purchasing_screen/add_purchasing_screen_controller.dart';
import 'package:traceability_app/screens/widgets/textfield_widget.dart';
import 'package:traceability_app/screens/widgets/button_widget.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class AddPurchasingScreen extends StatelessWidget {
  const AddPurchasingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => AddPurchasingController());

    return Obx(() {
      final isID = c.language.value == 'id';
      final loadingSources = c.loadingSources.value;
      final saving = c.saving.value;

      // snapshot all reactive values for use in subtree
      final plots = c.plots.toList();
      final warehouses = c.warehouses.toList();
      final commodities = c.commodities.toList();
      final grades = c.grades.toList();
      final selectedPlotId = c.selectedPlotId.value;
      final selectedGudangId = c.selectedGudangId.value;
      final selectedCoffeeId = c.selectedCoffeeId.value;
      final selectedGradeId = c.selectedGradeId.value;
      final proofValue = c.proofValueImage.value;
      final proofDeduction = c.proofDeductionImage.value;
      final proofPayment = c.proofPaymentImage.value;

      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            isID ? 'Tambah Pembelian' : 'Add Purchase',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
        body: loadingSources
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderBlock(
                      title: isID
                          ? 'Masukkan Data Pembelian'
                          : 'Enter Purchase Data',
                      subtitle: isID
                          ? 'Silakan lengkapi form di bawah ini dengan data yang benar'
                          : 'Please complete the form below with correct data',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Date
                    _SectionCard(
                      title: isID ? 'Tanggal' : 'Date',
                      icon: Icons.calendar_today_outlined,
                      children: [
                        _FieldLabel(isID ? 'Tanggal' : 'Date'),
                        GestureDetector(
                          onTap: () => c.selectDate(context),
                          child: AbsorbPointer(
                            child: Obx(() => TextFieldWidget(
                                  hintText:
                                      isID ? 'Pilih tanggal' : 'Select date',
                                  errorMessage: c.dateError.value,
                                  dataController: c.dateC,
                                )),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Plot & Warehouse
                    _SectionCard(
                      title: isID ? 'Plot & Gudang' : 'Plot & Warehouse',
                      icon: Icons.warehouse_outlined,
                      children: [
                        _FieldLabel(isID ? 'Plot' : 'Plot'),
                        Obx(() => _LabeledDropdown<int>(
                              value: selectedPlotId,
                              hint: isID ? 'Pilih Plot' : 'Select Plot',
                              errorText: c.plotError.value,
                              items: plots.map((p) {
                                final id = (p as dynamic).id as int?;
                                final name =
                                    (p as dynamic).plotName?.toString() ?? '-';
                                final farmerName = (p as dynamic)
                                    .farmer
                                    ?.farmerName
                                    ?.toString();
                                final label = farmerName == null
                                    ? name
                                    : '$name - $farmerName';
                                return DropdownMenuItem<int>(
                                    value: id, child: Text(label));
                              }).toList(),
                              onChanged: (v) {
                                c.selectedPlotId.value = v;
                                c.plotError.value = '';
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel(isID ? 'Gudang' : 'Warehouse'),
                        Obx(() => _LabeledDropdown<int>(
                              value: selectedGudangId,
                              hint: isID
                                  ? 'Pilih Gudang'
                                  : 'Select Warehouse',
                              errorText: c.gudangError.value,
                              items: warehouses.map((w) {
                                final id = (w as dynamic).id as int?;
                                final name = (w as dynamic)
                                        .warehouseName
                                        ?.toString() ??
                                    '-';
                                return DropdownMenuItem<int>(
                                    value: id, child: Text(name));
                              }).toList(),
                              onChanged: (v) {
                                c.selectedGudangId.value = v;
                                c.gudangError.value = '';
                              },
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Commodity & Grade
                    _SectionCard(
                      title: isID
                          ? 'Komoditas & Grade'
                          : 'Commodity & Grade',
                      icon: Icons.category_outlined,
                      children: [
                        _FieldLabel(isID ? 'Komoditas' : 'Commodity'),
                        Obx(() => _LabeledDropdown<int>(
                              value: selectedCoffeeId,
                              hint: isID
                                  ? 'Pilih Komoditas'
                                  : 'Select Commodity',
                              errorText: c.coffeeError.value,
                              items: commodities.map((cm) {
                                final id = (cm as dynamic).id as int?;
                                final name = (cm as dynamic)
                                        .commoditiesName
                                        ?.toString() ??
                                    '-';
                                return DropdownMenuItem<int>(
                                    value: id, child: Text(name));
                              }).toList(),
                              onChanged: (v) {
                                c.selectedCoffeeId.value = v;
                                c.coffeeError.value = '';
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel('Grade'),
                        Obx(() => _LabeledDropdown<int>(
                              value: selectedGradeId,
                              hint: isID ? 'Pilih Grade' : 'Select Grade',
                              errorText: c.gradeError.value,
                              items: grades.map((g) {
                                final id = (g as dynamic).id as int?;
                                final name =
                                    (g as dynamic).gradeName?.toString() ??
                                        '-';
                                return DropdownMenuItem<int>(
                                    value: id, child: Text(name));
                              }).toList(),
                              onChanged: (v) {
                                c.selectedGradeId.value = v;
                                c.gradeError.value = '';
                              },
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amounts
                    _SectionCard(
                      title: isID
                          ? 'Nilai & Perhitungan'
                          : 'Amounts & Calculation',
                      icon: Icons.calculate_outlined,
                      children: [
                        _FieldLabel(
                            isID ? 'Kuantitas (kg)' : 'Quantity (kg)'),
                        Obx(() => TextFieldWidget(
                              hintText: isID
                                  ? 'Masukkan kuantitas'
                                  : 'Enter quantity',
                              errorMessage: c.quantityError.value,
                              dataController: c.quantityC,
                              textInputType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,\.]'))
                              ],
                              onChange: (_) {
                                if (c.quantityC.text.isEmpty) {
                                  c.quantityError.value = isID
                                      ? 'Kuantitas tidak boleh kosong'
                                      : 'Quantity cannot be empty';
                                } else if (double.tryParse(c.quantityC.text
                                        .replaceAll(',', '.')) ==
                                    null) {
                                  c.quantityError.value = isID
                                      ? 'Kuantitas harus berupa angka'
                                      : 'Quantity must be a number';
                                } else {
                                  c.quantityError.value = '';
                                }
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel(isID
                            ? 'Harga per Kg (Rp)'
                            : 'Price per Kg (Rp)'),
                        Obx(() => TextFieldWidget(
                              hintText: isID
                                  ? 'Masukkan harga per kg'
                                  : 'Enter price per kg',
                              errorMessage: c.pricePerKgError.value,
                              dataController: c.pricePerKgC,
                              textInputType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,\.]'))
                              ],
                              onChange: (_) {
                                if (c.pricePerKgC.text.isEmpty) {
                                  c.pricePerKgError.value = isID
                                      ? 'Harga per kg tidak boleh kosong'
                                      : 'Price per kg cannot be empty';
                                } else if (double.tryParse(c.pricePerKgC.text
                                        .replaceAll(',', '.')) ==
                                    null) {
                                  c.pricePerKgError.value = isID
                                      ? 'Harga per kg harus berupa angka'
                                      : 'Price per kg must be a number';
                                } else {
                                  c.pricePerKgError.value = '';
                                }
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel(isID
                            ? 'Nilai Pembelian (Rp)'
                            : 'Purchase Value (Rp)'),
                        Obx(() => TextFieldWidget(
                              hintText: isID
                                  ? 'Otomatis dari Qty x Harga'
                                  : 'Auto from Qty x Price',
                              errorMessage: c.valuePurchasedError.value,
                              dataController: c.valuePurchasedC,
                              textInputType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,\.]'))
                              ],
                              onChange: (_) {
                                if (c.valuePurchasedC.text.isEmpty) {
                                  c.valuePurchasedError.value = isID
                                      ? 'Nilai pembelian tidak boleh kosong'
                                      : 'Purchase value cannot be empty';
                                } else if (double.tryParse(
                                        c.valuePurchasedC.text
                                            .replaceAll(',', '.')) ==
                                    null) {
                                  c.valuePurchasedError.value = isID
                                      ? 'Nilai pembelian harus berupa angka'
                                      : 'Purchase value must be a number';
                                } else {
                                  c.valuePurchasedError.value = '';
                                }
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel(
                            isID ? 'Potongan (Rp)' : 'Deduction (Rp)'),
                        Obx(() => TextFieldWidget(
                              hintText: isID
                                  ? 'Masukkan potongan'
                                  : 'Enter deduction',
                              errorMessage: c.deductionError.value,
                              dataController: c.deductionC,
                              textInputType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,\.]'))
                              ],
                              onChange: (_) {
                                if (c.deductionC.text.isEmpty) {
                                  c.deductionError.value = isID
                                      ? 'Potongan tidak boleh kosong'
                                      : 'Deduction cannot be empty';
                                } else if (double.tryParse(c.deductionC.text
                                        .replaceAll(',', '.')) ==
                                    null) {
                                  c.deductionError.value = isID
                                      ? 'Potongan harus berupa angka'
                                      : 'Deduction must be a number';
                                } else {
                                  c.deductionError.value = '';
                                }
                              },
                            )),
                        const SizedBox(height: 14),
                        _FieldLabel(isID
                            ? 'Pembayaran Bersih (Rp)'
                            : 'Net Payment (Rp)'),
                        TextFieldWidget(
                          hintText: isID
                              ? 'Otomatis dihitung'
                              : 'Automatically calculated',
                          errorMessage: '',
                          dataController: c.netPaymentC,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Images
                    _SectionCard(
                      title: isID
                          ? 'Bukti Transaksi'
                          : 'Transaction Proofs',
                      icon: Icons.image_outlined,
                      children: [
                        _ImagePickerTile(
                          label: isID
                              ? 'Bukti Nilai Pembelian'
                              : 'Purchase Value Proof',
                          file: proofValue,
                          onTap: () => c.pickImage('value'),
                        ),
                        const SizedBox(height: 12),
                        _ImagePickerTile(
                          label: isID
                              ? 'Bukti Potongan'
                              : 'Deduction Proof',
                          file: proofDeduction,
                          onTap: () => c.pickImage('deduction'),
                        ),
                        const SizedBox(height: 12),
                        _ImagePickerTile(
                          label: isID
                              ? 'Bukti Pembayaran'
                              : 'Payment Proof',
                          file: proofPayment,
                          onTap: () => c.pickImage('payment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ButtonWidget(
                      textButton: saving
                          ? (isID ? 'Menyimpan...' : 'Saving...')
                          : (isID ? 'Simpan' : 'Save'),
                      route: '',
                      onPressed: saving ? null : () => c.save(context),
                    ),
                  ],
                ),
              ),
      );
    });
  }
}

// ——— Themed helpers (pure StatelessWidget — no controller dependency) ———

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _HeaderBlock(
      {required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient:
            LinearGradient(colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md)),
          child: Icon(icon, color: ThemeColor.darkestGreen, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ThemeTextStyle
                        .textStyleForthBold
                        .copyWith(fontSize: 18, color: ThemeColor.darkestGreen)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(Insets.sm),
            decoration: BoxDecoration(
                color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: ThemeColor.darkestGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: ThemeTextStyle
                  .textStyleForthBold
                  .copyWith(color: ThemeColor.darkestGreen)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
            color: ThemeColor.darkestGreen,
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final String? errorText;
  final ValueChanged<T?>? onChanged;

  const _LabeledDropdown({
    required this.value,
    required this.items,
    required this.hint,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide:
                    BorderSide(color: ThemeColor.darkestGreen)),
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(errorText!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const _ImagePickerTile(
      {required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(Radii.md),
              border:
                  Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Image.file(file!,
                        fit: BoxFit.cover, width: double.infinity),
                  )
                : Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            color: ThemeColor.darkestGreen),
                        const SizedBox(width: 8),
                        Text('Tap to upload',
                            style: ThemeTextStyle
                                .textStyleForthDarkestGreen),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
