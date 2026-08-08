import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:traceability_app/models/api/login_petani_api.dart';
import 'package:traceability_app/screens/login_screen/login_petani_controller.dart';
import 'package:traceability_app/screens/widgets/button_widget.dart';
import 'package:traceability_app/screens/widgets/textfield_widget.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/app_tokens.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

class LoginPetaniScreen extends StatelessWidget {
  const LoginPetaniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ControllerRegistry.lazyPut(
      () => LoginPetaniController(LoginPetaniApi()),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
            final logoSize = (constraints.maxHeight * 0.22)
                .clamp(120.0, 220.0);

            return Obx(() {
              final isID = LanguageService.to.language.value == 'id';

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.lg,
                  Insets.lg,
                  Insets.lg + viewInsets,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        (Insets.lg * 2) -
                        viewInsets,
                    maxWidth: 480,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.04),
                      Center(
                        child: Image.asset(
                          'assets/logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        isID
                            ? 'Selamat Datang di App Traceability'
                            : 'Welcome to Traceability App',
                        style: ThemeTextStyle.labelLarge.copyWith(
                          fontSize: 26,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        isID ? 'Halaman Login Petani' : 'Farmer Login',
                        style: ThemeTextStyle.textStyleSecond.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Obx(() {
                        final error = controller.errorMessage.value;
                        if (error == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(Insets.sm),
                          margin: const EdgeInsets.only(bottom: Insets.lg),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: Insets.sm),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextFieldWidget(
                        labelText: 'Username',
                        hintText: isID ? 'Masukkan username' : 'Enter username',
                        errorMessage: '',
                        dataController: controller.usernameController,
                        textInputAction: TextInputAction.next,
                        onChange: (_) => controller.clearError(),
                      ),
                      const SizedBox(height: Insets.md),
                      Obx(
                        () => TextFieldWidget(
                          labelText: 'Password',
                          hintText: isID
                              ? 'Masukkan password'
                              : 'Enter password',
                          errorMessage: '',
                          dataController: controller.passwordController,
                          obscure: !controller.isPasswordVisible.value,
                          textInputAction: TextInputAction.done,
                          onChange: (_) {},
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.isPasswordVisible.value
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: controller.togglePasswordVisibility,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      Obx(
                        () => controller.isLoading.value
                            ? const Center(child: CircularProgressIndicator())
                            : ButtonWidget(
                                textButton: isID ? 'Masuk' : 'Log In',
                                route: '',
                                onPressed: () => controller.login(context),
                              ),
                      ),
                      const SizedBox(height: Insets.md),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/login-koperasi'),
                          child: Text(
                            isID
                                ? 'Ke halaman login Partners'
                                : 'Go to Partners login',
                            style: TextStyle(
                              color: ThemeColor.darkestGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }
}
