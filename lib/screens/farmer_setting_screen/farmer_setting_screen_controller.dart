import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/farmer_api.dart';
import 'package:traceability_app/models/get_farmer_by_id.dart';
import 'package:traceability_app/screens/login_screen/login_petani_screen.dart';
import 'package:traceability_app/services/language_service.dart';

class FarmerSettingController extends GetxController {
  final _api = FarmerApi();

  final language  = LanguageService.to.language;
  final isLoading = false.obs;
  final busy      = false.obs;
  final error     = RxnString();
  final profile   = Rxn<Data>();

  bool _didAutoLogout = false;

  @override
  void onInit() {
    super.onInit();
    FarmerApi.startAutoSyncListener();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt('id') ?? 0;
      if (id == 0) {
        throw Exception(language.value == 'id'
            ? 'Farmer ID tidak ditemukan. Silakan login ulang.'
            : 'Farmer ID not found. Please log in again.');
      }
      final res = await _api.getFarmerByIdCached(id);
      if (res.data == null) {
        // getFarmerByIdCached swallows failures and returns data:null; surface a
        // real error (with retry) instead of silently rendering blank placeholders.
        error.value = language.value == 'id'
            ? 'Gagal memuat data petani. Periksa koneksi lalu coba lagi.'
            : 'Failed to load farmer data. Check your connection and retry.';
        return;
      }
      profile.value = res.data;
    } catch (e) {
      error.value = e.toString();
      _scheduleAutoLogout(e);
    } finally {
      isLoading.value = false;
    }
  }

  void _scheduleAutoLogout(Object e) {
    if (_didAutoLogout) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLogout(e));
  }

  Future<void> _autoLogout(Object e) async {
    if (_didAutoLogout) return;
    final msg = e.toString().toLowerCase();
    final shouldLogout =
        msg.contains('farmer id tidak ditemukan') ||
        msg.contains('farmer id not found') ||
        msg.contains('online-error-no-cache') ||
        msg.contains('unauthorized') ||
        msg.contains('401') ||
        (msg.contains('token') && msg.contains('expired'));
    if (!shouldLogout) return;

    _didAutoLogout = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.deleteAll();

    Get.rawSnackbar(
      message: language.value == 'id'
          ? 'Sesi berakhir. Silakan login ulang.'
          : 'Session expired. Please log in again.',
      duration: const Duration(seconds: 3),
    );
    Get.offAll(() => const LoginPetaniScreen());
  }

  Future<void> forceLogoutNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.deleteAll();
    Get.offAll(() => const LoginPetaniScreen());
  }

  void showLogoutDialog() {
    final isID = language.value == 'id';
    Get.dialog(
      AlertDialog(
        title: Text(isID
            ? 'Apakah Anda Ingin Keluar?'
            : 'Do you want to log out?'),
        content: Text(isID
            ? 'Anda akan keluar dari akun ini.'
            : 'You will be logged out from this account.'),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Get.deleteAll();
              Get.offAll(() => const LoginPetaniScreen());
            },
            child: Text(isID ? 'Iya' : 'Yes'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text(isID ? 'Tidak' : 'No'),
          ),
        ],
      ),
    );
  }

  Future<void> openLanguage(BuildContext context) async {
    final changed = await Navigator.pushNamed(context, '/language');
    if (changed == true) await load();
  }

  Future<String?> promptText({
    required String title,
    required String initial,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) async {
    final isID = language.value == 'id';
    final ctrl = TextEditingController(text: initial);
    final result = await Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(isID ? 'Batal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: ctrl.text.trim()),
            child: Text(isID ? 'Simpan' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> updateServer(
    BuildContext context,
    Map<String, dynamic> fields,
    String successMessage,
  ) async {
    busy.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmerId = prefs.getInt('id') ?? 0;
      final op = await _api.updateFarmerAllOfflineFirst(farmerId, fields);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              op.message.isNotEmpty ? op.message : successMessage),
        ));
      }
      await load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      busy.value = false;
    }
  }

  // ── Format helpers ──────────────────────────────────────────────────────

  String fmtDate(DateTime d, bool isID) {
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const id = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final arr = isID ? id : en;
    return '${d.day.toString().padLeft(2, '0')} ${arr[d.month - 1]} ${d.year}';
  }

  String fmtDateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String fmtCurrencyID(num? v) {
    if (v == null) return '-';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) buf.write('.');
    }
    return 'Rp ${buf.toString().split('').reversed.join()}';
  }

  // ── Account updaters ────────────────────────────────────────────────────

  Future<void> editName(BuildContext context, String current) async {
    final isID = language.value == 'id';
    final v = await promptText(
      title: isID ? 'Ubah Nama' : 'Change Name',
      initial: current,
      hint: isID ? 'contoh: Andri Tirta' : 'e.g. Andri Tirta',
    );
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    await updateServer(context, {'farmer_name': v},
        isID ? 'Nama diperbarui' : 'Name updated');
  }

  Future<void> editNik(BuildContext context, String current) async {
    final v = await promptText(
      title: 'Ubah NIK',
      initial: current,
      keyboardType: TextInputType.number,
      hint: '16 digit',
    );
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    await updateServer(context, {'nik': v}, 'NIK diperbarui');
  }

  Future<void> editPhone(BuildContext context, String current) async {
    final isID = language.value == 'id';
    final v = await promptText(
      title: isID ? 'Ubah Nomor HP' : 'Change Phone',
      initial: current,
      keyboardType: TextInputType.phone,
      hint: '08xxxxxxxxxx',
    );
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    await updateServer(context, {'no_hp': v},
        isID ? 'Nomor HP diperbarui' : 'Phone updated');
  }

  Future<void> editAddress(BuildContext context, String current) async {
    final isID = language.value == 'id';
    final v = await promptText(
      title: isID ? 'Ubah Alamat' : 'Change Address',
      initial: current,
      hint: isID ? 'contoh: Jl. Mawar No. 1' : 'e.g. 123 Main St',
    );
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    await updateServer(context, {'address': v},
        isID ? 'Alamat diperbarui' : 'Address updated');
  }

  Future<void> editDOB(BuildContext context, DateTime? current) async {
    final isID = language.value == 'id';
    final now = DateTime.now();
    final initial =
        current ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      initialDate: initial,
    );
    if (picked == null) return;
    if (!context.mounted) return;
    await updateServer(
      context,
      {'date_of_birth': fmtDateIso(picked)},
      isID ? 'Tanggal lahir diperbarui' : 'Date of birth updated',
    );
  }

  // ── Finance updaters ────────────────────────────────────────────────────

  Future<void> updateNoRek(BuildContext context, String current) async {
    final isID = language.value == 'id';
    final newVal = await promptText(
      title: isID ? 'Ubah No Rekening' : 'Change Account Number',
      initial: current,
      keyboardType: TextInputType.number,
      hint: isID ? 'contoh: 4567' : 'e.g. 4567',
    );
    if (newVal == null) return;
    if (newVal.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isID
              ? 'No rekening tidak boleh kosong'
              : 'Account number cannot be empty'),
        ));
      }
      return;
    }
    if (!context.mounted) return;
    await updateServer(
      context,
      {'no_rek': newVal},
      isID ? 'No rekening berhasil diperbarui' : 'Account number updated',
    );
  }

  Future<void> updateIncome(BuildContext context, num current) async {
    final isID = language.value == 'id';
    final newValStr = await promptText(
      title: isID
          ? 'Ubah Penghasilan Sebelumnya'
          : 'Change Previous Income',
      initial: current == 0 ? '' : current.toString(),
      keyboardType: TextInputType.number,
      hint: isID ? 'contoh: 3000000' : 'e.g. 3000000',
    );
    if (newValStr == null) return;
    final parsed = num.tryParse(
        newValStr.replaceAll('.', '').replaceAll(',', ''));
    if (parsed == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isID ? 'Nilai tidak valid' : 'Invalid value'),
        ));
      }
      return;
    }
    if (!context.mounted) return;
    await updateServer(
      context,
      {'previous_income': parsed},
      isID ? 'Penghasilan berhasil diperbarui' : 'Income updated',
    );
  }
}
