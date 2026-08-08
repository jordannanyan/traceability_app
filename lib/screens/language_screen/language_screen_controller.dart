import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:traceability_app/services/language_service.dart';

class LanguageController extends GetxController {
  final saving = false.obs;

  RxString get selected => LanguageService.to.language;

  Future<void> setLanguage(String code, BuildContext context) async {
    if (saving.value || code == selected.value) {
      if (context.mounted) Navigator.pop(context, true);
      return;
    }
    saving.value = true;
    await LanguageService.to.setLanguage(code);
    saving.value = false;
    if (context.mounted) Navigator.pop(context, true);
  }
}
