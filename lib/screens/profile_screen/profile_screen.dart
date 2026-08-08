import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/profile_screen/profile_screen_controller.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => ProfileController());

    return Obx(() {
      final isID = c.language.value == 'id';
      final isLoading = c.isLoading.value;
      final profile = c.profile.value;
      final errorMsg = c.error.value;

      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            isID ? 'Profil' : 'Profile',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
        body: () {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMsg != null) {
            return Center(child: Text('Error: $errorMsg'));
          }

          if (profile == null) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Avatar
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[300],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.name ?? 'Unknown',
                        style: ThemeTextStyle.textStyleFirstBold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Details
                ListTile(
                  leading:
                      Icon(Icons.person, color: ThemeColor.darkGreen),
                  title: Text(isID ? 'Nama' : 'Name'),
                  subtitle: Text(profile.name ?? '-'),
                ),
                const Divider(),
                ListTile(
                  leading:
                      Icon(Icons.person, color: ThemeColor.darkGreen),
                  title: const Text('Username'),
                  subtitle: Text(profile.username ?? '-'),
                ),
              ],
            ),
          );
        }(),
      );
    });
  }
}
