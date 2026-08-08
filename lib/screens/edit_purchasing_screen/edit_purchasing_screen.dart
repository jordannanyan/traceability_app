import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:traceability_app/models/get_purchasing_by_kth_id.dart' as kth;
import 'package:traceability_app/screens/edit_purchasing_screen/edit_purchasing_screen_controller.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class EditPurchasingScreen extends StatelessWidget {
  const EditPurchasingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final datum = args is kth.Datum ? args : null;

    final c = Get.put(EditPurchasingController(datum: datum));

    return Obx(() {
      final isID          = LanguageService.to.language.value == 'id';
      final saving        = c.saving.value;
      final isOffline     = c.isOfflineView.value;
      final autoCalc      = c.autoCalc.value;
      final dateStr       = c.fmtDate();
      final proofValue    = c.proofValue.value;
      final proofDeduction = c.proofDeduction.value;
      final proofPayment  = c.proofPayment.value;
      final green         = ThemeColor.darkestGreen;

      return Scaffold(
        appBar: AppBar(
          title: Text(isID ? 'Edit Pembelian' : 'Edit Purchase'),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(context),
              child: Text(isID ? 'Batal' : 'Cancel',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.lg + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            // Offline banner
            if (isOffline)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5CC),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isID
                            ? 'Mode offline: perubahan akan diantre dan disinkronkan saat online.'
                            : 'Offline mode: changes will be queued and synced when online.',
                      ),
                    ),
                  ],
                ),
              ),

            // Header
            _headerCard(c, isID),
            const SizedBox(height: 16),

            // Form
            _formCard(context, c, dateStr, autoCalc, isID),
            const SizedBox(height: 16),

            // Proofs
            _proofsCard(c, proofValue, proofDeduction, proofPayment, isID),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : () => c.save(context),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving
                      ? (isID ? 'Menyimpan...' : 'Saving...')
                      : (isID ? 'Simpan Perubahan' : 'Save Changes'),
                  style: ThemeTextStyle.textStyleFirstBoldWhite,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _headerCard(EditPurchasingController c, bool isID) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.receipt_long,
                color: ThemeColor.darkestGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isID ? 'Detail Transaksi' : 'Transaction Details',
                  style: ThemeTextStyle.textStyleForthBold.copyWith(
                      fontSize: 18,
                      color: ThemeColor.darkestGreen),
                ),
                const SizedBox(height: 6),
                Wrap(
                  runSpacing: 6,
                  spacing: 8,
                  children: [
                    _chip(Icons.landscape,  c.plotName),
                    _chip(Icons.warehouse,  c.warehouseName),
                    _chip(Icons.category,   c.commodityName),
                    _chip(Icons.grade,      c.gradeName),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.green),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _formCard(BuildContext context, EditPurchasingController c,
      String dateStr, bool autoCalc, bool isID) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: _cardDeco(),
      child: Form(
        key: c.formKey,
        child: Column(
          children: [
            _fieldLabel(isID ? 'Tanggal' : 'Date'),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => c.pickDate(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(dateStr),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_outlined,
                        size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                  child: _numField(
                      isID ? 'Jumlah (kg)' : 'Quantity (kg)', c.qtyC,
                      hint: isID ? 'contoh: 100' : 'e.g. 100', isID: isID)),
              const SizedBox(width: 12),
              Expanded(
                  child: _numField(
                      isID ? 'Harga/kg' : 'Price/kg', c.priceC,
                      hint: isID ? 'contoh: 7000' : 'e.g. 7000', isID: isID)),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                  child: _numField(
                      isID ? 'Nilai Pembelian (Rp)' : 'Purchase Value (Rp)',
                      c.valueC,
                      hint: isID ? 'otomatis' : 'automatic',
                      canBeEmpty: true,
                      isID: isID)),
              const SizedBox(width: 12),
              Expanded(
                  child: _numField(
                      isID ? 'Potongan (Rp)' : 'Deduction (Rp)', c.deductionC,
                      hint: '0', isID: isID)),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                  child: _numField(
                      isID ? 'Pembayaran Bersih (Rp)' : 'Net Payment (Rp)',
                      c.netC,
                      hint: isID ? 'otomatis' : 'automatic',
                      canBeEmpty: true,
                      isID: isID)),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isID ? 'Hitung Otomatis' : 'Auto Calculate',
                      style: const TextStyle(fontSize: 12)),
                  value: autoCalc,
                  onChanged: c.toggleAutoCalc,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _proofsCard(
    EditPurchasingController c,
    File? proofValue,
    File? proofDeduction,
    File? proofPayment,
    bool isID,
  ) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isID ? 'Bukti (Opsional)' : 'Proof (Optional)',
              style: ThemeTextStyle.textStyleForthBold),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _proofTile(
                    isID ? 'Nilai Pembelian' : 'Purchase Value',
                    proofValue,
                    () => c.pickProof('value'),
                    isID)),
            const SizedBox(width: 10),
            Expanded(
                child: _proofTile(isID ? 'Potongan' : 'Deduction',
                    proofDeduction, () => c.pickProof('deduction'), isID)),
            const SizedBox(width: 10),
            Expanded(
                child: _proofTile(isID ? 'Pembayaran' : 'Payment',
                    proofPayment, () => c.pickProof('payment'), isID)),
          ]),
        ],
      ),
    );
  }

  Widget _proofTile(String label, File? file, VoidCallback onPick, bool isID) {
    final has = file != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        height: 88,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: ThemeColor
                    .darkestGreen
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(
                  has ? Icons.image : Icons.upload_file,
                  size: 22,
                  color: ThemeColor.darkestGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                has
                    ? file.path.split('/').last
                    : '$label ${isID ? '(unggah)' : '(upload)'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child:
            Text(text, style: ThemeTextStyle.textStyleForthBold),
      );

  Widget _numField(String label, TextEditingController ctrl,
      {String? hint, bool canBeEmpty = false, bool isID = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: false),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'))
          ],
          validator: (v) {
            final s = (v ?? '').trim();
            if (!canBeEmpty && s.isEmpty) {
              return isID ? 'Wajib diisi' : 'Required';
            }
            if (s.isEmpty) return null;
            if (double.tryParse(s.replaceAll(',', '.')) == null) {
              return isID ? 'Tidak valid' : 'Invalid';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: ThemeColor.darkestGreen),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50]),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      );
}
