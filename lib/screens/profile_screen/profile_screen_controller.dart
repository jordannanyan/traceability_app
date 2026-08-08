import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/pengepul_api.dart';
import 'package:traceability_app/models/pengepul_model.dart';
import 'package:traceability_app/screens/login_screen/login_petani_screen.dart';
import 'package:traceability_app/services/language_service.dart';

class ProfileController extends GetxController {
  final _api = PengepulApi();

  final language = LanguageService.to.language;
  final isLoading = false.obs;
  final profile = Rxn<PengepulModel>();
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    error.value = null;
    try {
      final data = await _api.fetchPengepulDataCached();
      profile.value = data;
    } on UnauthorizedException catch (e) {
      await _forceLogout(e.toString());
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('expired') ||
          msg.contains('Unauthorized') ||
          msg.contains('Token') ||
          msg.contains('401') ||
          msg.contains('500')) {
        await _forceLogout(msg);
      } else {
        error.value = msg;
        Get.snackbar(
          'Error',
          msg,
          backgroundColor: const Color(0xFFFF5252),
          colorText: const Color(0xFFFFFFFF),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _forceLogout(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Get.deleteAll();
    Get.offAll(() => const LoginPetaniScreen());
  }
}
