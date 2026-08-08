import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _buildSection({
    required String title,
    required String content,
    IconData icon = Icons.info_outline,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                icon,
                color: ThemeColor.darkestGreen,
              ),
              title: Text(
                title,
                style: ThemeTextStyle.textStyleThirdBold.copyWith(
                      color: ThemeColor.darkestGreen,
                    ),
              ),
              childrenPadding: const EdgeInsets.all(Insets.lg),
              children: [
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final language = LanguageService.to.language.value;
      return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          language == "id" ? "Kebijakan Privasi" : "Privacy Policy",
          style: ThemeTextStyle.textStyleFirstBoldWhite,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThemeColor.darkestGreen,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.only(
                bottom: 20,
                left: 20,
                right: 20,
                top: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    language == "id" ? "Kebijakan Privasi" : "Privacy Policy",
                    style: ThemeTextStyle.textStyleFirstBoldWhite,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    language == "id"
                        ? "Kami menghargai privasi Anda dan berkomitmen untuk melindungi informasi pribadi Anda."
                        : "We respect your privacy and are committed to protecting your personal information.",
                    style: TextStyle(
                      color: ThemeColor.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                children: [
                  _buildSection(
                    title: language == "id"
                        ? "Informasi yang Kami Kumpulkan"
                        : "Information We Collect",
                    content: language == "id"
                        ? "• Data pribadi seperti nama, nomor telepon, dan lokasi yang Anda berikan saat mendaftar.\n"
                            "• Informasi tentang penggunaan aplikasi untuk meningkatkan pengalaman Anda."
                        : "• Personal data such as name, phone number, and location that you provide when registering.\n"
                            "• Information about app usage to enhance your experience.",
                    icon: Icons.folder_shared,
                  ),
                  _buildSection(
                    title: language == "id"
                        ? "Bagaimana Kami Menggunakan Informasi Anda"
                        : "How We Use Your Information",
                    content: language == "id"
                        ? "• Untuk memberikan layanan dan fitur aplikasi yang lebih baik.\n"
                            "• Untuk menghubungi Anda terkait pembaruan atau masalah pada akun Anda."
                        : "• To provide better services and app features.\n"
                            "• To contact you regarding updates or issues with your account.",
                    icon: Icons.description,
                  ),
                  _buildSection(
                    title: language == "id"
                        ? "Bagaimana Kami Melindungi Informasi Anda"
                        : "How We Protect Your Information",
                    content: language == "id"
                        ? "Kami menggunakan langkah-langkah keamanan yang sesuai untuk melindungi data Anda dari akses yang tidak sah atau kehilangan."
                        : "We use appropriate security measures to protect your data from unauthorized access or loss.",
                    icon: Icons.shield,
                  ),
                  _buildSection(
                    title: language == "id"
                        ? "Perubahan pada Kebijakan Privasi"
                        : "Changes to Privacy Policy",
                    content: language == "id"
                        ? "Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu. Pembaruan akan diberitahukan melalui aplikasi."
                        : "We may update this Privacy Policy from time to time. Updates will be notified via the app.",
                    icon: Icons.update,
                  ),
                  _buildSection(
                    title: language == "id"
                        ? "Hubungi Kami"
                        : "Contact Us",
                    content: language == "id"
                        ? "Jika Anda memiliki pertanyaan mengenai Kebijakan Privasi ini, silakan hubungi kami melalui halaman Hubungi Kami di aplikasi."
                        : "If you have any questions regarding this Privacy Policy, please contact us through the Contact Us page in the app.",
                    icon: Icons.contact_support,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    });
  }
}
