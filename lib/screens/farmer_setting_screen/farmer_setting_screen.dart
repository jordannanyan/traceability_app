import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/farmer_setting_screen/farmer_setting_screen_controller.dart';
import 'package:traceability_app/screens/farmer_setting_screen/farmer_setting_screen_widget/farmer_settings_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class FarmerSettingScreen extends StatelessWidget {
  const FarmerSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => FarmerSettingController());

    return Obx(() {
      final isLoading = c.isLoading.value;
      final errorMsg  = c.error.value;
      final busy      = c.busy.value;
      final isID      = c.language.value == 'id';
      final data      = c.profile.value;

      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(isID ? 'Pengaturan' : 'Settings'),
          titleTextStyle: ThemeTextStyle.textStyleFirstBoldWhite,
        ),
        body: Stack(
          children: [
            _buildBody(context, c, isLoading, errorMsg, busy, isID, data),
            if (busy)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        bottomNavigationBar:
            const BottomNavigationBarWidget(currentIndex: 2),
      );
    });
  }

  Widget _buildBody(
    BuildContext context,
    FarmerSettingController c,
    bool isLoading,
    String? errorMsg,
    bool busy,
    bool isID,
    dynamic data,
  ) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMsg,
                textAlign: TextAlign.center,
                style: ThemeTextStyle
                    .textStyleForthBold
                    .copyWith(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: c.load,
                child: Text(isID ? 'Coba Lagi' : 'Try Again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: c.forceLogoutNow,
                child: Text(
                    isID ? 'Keluar & Login Ulang' : 'Logout & Re-login'),
              ),
            ],
          ),
        ),
      );
    }

    final name       = data?.farmerName ?? 'Ahmad';
    final kthName    = data?.kth?.kthName ?? '-';
    final phone      = data?.noHp ?? '-';
    final nik        = data?.nik ?? '-';
    final addr       = data?.address ?? '-';
    final noRek      = (data?.noRek ?? '') as String;
    final prevIncome = (data?.previousIncome ?? 0) as num;

    DateTime? dob;
    final rawDob = data?.dateOfBirth;
    if (rawDob is DateTime) dob = rawDob;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Header
        HeaderCard(
          name: name,
          role: isID ? 'Petani' : 'Farmer',
          subtitle: kthName.isNotEmpty ? 'KTH: $kthName' : null,
          photoPrimaryUrl: buildPhotoUrlPrimary(data?.foto),
          photoFallbackUrl: buildPhotoUrlFallback(data?.foto),
        ),

        const SizedBox(height: 16),

        // Account (editable)
        SectionCard(
          title: isID ? 'Akun' : 'Account',
          children: [
            SettingsTile(
              icon: Icons.person_outline,
              title: isID ? 'Nama' : 'Name',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy ? null : () => c.editName(context, name),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.credit_card_outlined,
              title: 'NIK',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nik,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy ? null : () => c.editNik(context, nik),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.cake_outlined,
              title: isID ? 'Tanggal Lahir' : 'Date of Birth',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dob != null ? c.fmtDate(dob, isID) : '-',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy ? null : () => c.editDOB(context, dob),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.phone_outlined,
              title: isID ? 'Nomor HP' : 'Phone',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(phone,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy ? null : () => c.editPhone(context, phone),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.home_outlined,
              title: isID ? 'Alamat' : 'Address',
              subtitle: addr,
              trailing: const Icon(Icons.edit_outlined,
                  size: 18, color: Colors.grey),
              onTap: busy ? null : () => c.editAddress(context, addr),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Finance (editable)
        SectionCard(
          title: isID ? 'Keuangan' : 'Finance',
          children: [
            SettingsTile(
              icon: Icons.account_balance_outlined,
              title: isID ? 'No Rekening' : 'Account Number',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    noRek.isEmpty ? '-' : noRek,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy ? null : () => c.updateNoRek(context, noRek),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.payments_outlined,
              title: isID
                  ? 'Penghasilan Sebelumnya'
                  : 'Previous Income',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.fmtCurrencyID(prevIncome),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.grey),
                ],
              ),
              onTap: busy
                  ? null
                  : () => c.updateIncome(context, prevIncome),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // App section
        SectionCard(
          title: isID ? 'Aplikasi' : 'App',
          children: [
            SettingsTile(
              icon: Icons.language_outlined,
              title: isID ? 'Bahasa' : 'Language',
              trailing: Text(
                isID ? 'Indonesia' : 'English',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () => c.openLanguage(context),
            ),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.policy_outlined,
              title: isID ? 'Kebijakan Privasi' : 'Privacy Policy',
              onTap: () =>
                  Navigator.pushNamed(context, '/privacy-policy'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Security / Logout
        SectionCard(
          title: isID ? 'Keamanan' : 'Security',
          children: [
            SettingsTile(
              icon: Icons.logout,
              title: isID ? 'Keluar' : 'Logout',
              iconColor: Colors.red,
              titleColor: Colors.red,
              onTap: c.showLogoutDialog,
            ),
          ],
        ),
      ],
    );
  }
}
