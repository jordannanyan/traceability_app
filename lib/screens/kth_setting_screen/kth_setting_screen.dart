import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_setting_screen/kth_setting_controller.dart';
import 'package:traceability_app/screens/kth_setting_screen/kth_setting_screen_widget/settings_header_card_widget.dart';
import 'package:traceability_app/screens/kth_setting_screen/kth_setting_screen_widget/settings_section_card_widget.dart';
import 'package:traceability_app/screens/kth_setting_screen/kth_setting_screen_widget/settings_tile_widget.dart';
import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/offline_banner.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class KthSettingScreen extends StatelessWidget {
  const KthSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => KthSettingController());

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(
          () => Text(
            c.language.value == 'id'
                ? 'Pengaturan Partner'
                : 'Partner Settings',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
      ),
      body: Obx(() {
        final isID = c.language.value == 'id';

        if (c.isLoading.value &&
            c.data.value == null &&
            c.error.value == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (c.error.value != null && c.data.value == null) {
          c.scheduleAutoLogoutIfNeeded(c.error.value, context);

          return ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              if (c.isOfflineView.value) OfflineBanner(isID: isID),
              const SizedBox(height: 12),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.error.value!,
                        textAlign: TextAlign.center,
                        style: ThemeTextStyle.textStyleForthBold.copyWith(
                              color: Colors.red,
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: c.load,
                        child: Text(isID ? 'Coba Lagi' : 'Try Again'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => c.forceLogoutNow(context),
                        child: Text(
                          isID
                              ? 'Keluar & Login Ulang'
                              : 'Logout & Re-login',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final data = c.data.value;
        final kthName = data?.kthName ?? '-';
        final entityName = data?.entity?.entitiesName ?? '-';
        final regency = data?.regency ?? '-';
        final address = data?.address ?? '-';
        final period = data?.partnershipPeriod ?? '-';
        final username = data?.username ?? '-';

        return RefreshIndicator(
          onRefresh: c.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                if (c.isOfflineView.value) OfflineBanner(isID: isID),

                SettingsHeaderCard(
                  name: kthName,
                  role: 'Partner',
                  subtitle: entityName.isNotEmpty
                      ? (isID ? 'Entitas: ' : 'Entity: ') + entityName
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.history, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${isID ? 'Terakhir sinkron' : 'Last sync'}: ${c.fmtLastSync(c.lastSync.value)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SettingsSectionCard(
                  title: isID ? 'Profil Partner' : 'Partner Profile',
                  children: [
                    SettingsTile(
                      icon: Icons.badge_outlined,
                      title: isID ? 'Nama Partner' : 'Partner Name',
                      trailing: _GreyText(kthName),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.account_circle_outlined,
                      title: 'Username',
                      trailing: _GreyText(username),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.domain_outlined,
                      title: isID ? 'Kabupaten' : 'Regency',
                      trailing: _GreyText(regency),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.calendar_month_outlined,
                      title: isID
                          ? 'Periode Kemitraan'
                          : 'Partnership Period',
                      trailing: _GreyText(period),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.location_on_outlined,
                      title: isID ? 'Alamat' : 'Address',
                      subtitle: address,
                      trailing: const SizedBox.shrink(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SettingsSectionCard(
                  title: isID ? 'Aplikasi' : 'App',
                  children: [
                    SettingsTile(
                      icon: Icons.language_outlined,
                      title: isID ? 'Bahasa' : 'Language',
                      trailing: _GreyText(isID ? 'Indonesia' : 'English'),
                      onTap: () => c.openLanguage(context),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.policy_outlined,
                      title:
                          isID ? 'Kebijakan Privasi' : 'Privacy Policy',
                      onTap: () =>
                          Navigator.pushNamed(context, '/privacy-policy'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SettingsSectionCard(
                  title: isID ? 'Keamanan' : 'Security',
                  children: [
                    SettingsTile(
                      icon: Icons.logout,
                      title: isID ? 'Keluar' : 'Logout',
                      iconColor: Colors.red,
                      titleColor: Colors.red,
                      onTap: () => c.logout(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen-specific small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GreyText extends StatelessWidget {
  final String text;

  const _GreyText(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.grey));
}
