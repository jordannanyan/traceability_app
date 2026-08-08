import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/models/api/login_kth_api.dart';
import 'package:traceability_app/models/login_kth_model.dart';

class LoginKthController extends GetxController {
  final LoginKthApi _loginApi;

  LoginKthController(this._loginApi);

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final errorMessage = RxnString();

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() => isPasswordVisible.toggle();
  void clearError() => errorMessage.value = null;

  Future<void> login(BuildContext context) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please fill in both fields';
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final loginModel = await _loginApi.login(username, password);
      if (!context.mounted) return;
      await _saveAndNavigate(loginModel, context);
    } catch (e) {
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveAndNavigate(
    LoginModel loginModel,
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', loginModel.kth?.kthName ?? '');
    await prefs.setInt('id', loginModel.kth?.id ?? 1);
    await prefs.setString('token', loginModel.token ?? '');
    await prefs.setBool('login', true);
    await prefs.setString('login_as', 'kth');

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }
}
