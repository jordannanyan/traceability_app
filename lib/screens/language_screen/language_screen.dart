import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/language_screen/language_screen_controller.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/utils/controller_registry.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerRegistry.lazyPut(() => LanguageController());

    return Obx(() {
      final selected = c.selected.value;
      final saving = c.saving.value;

      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Bahasa',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
        body: AbsorbPointer(
          absorbing: saving,
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              Text(
                'Pilih Bahasa',
                style: ThemeTextStyle.textStyleSecondBold,
              ),
              const SizedBox(height: 16),

              _LanguageTile(
                title: 'Indonesia',
                selected: selected == 'id',
                onTap: () => c.setLanguage('id', context),
              ),
              const Divider(height: 1),

              _LanguageTile(
                title: 'English',
                selected: selected == 'en',
                onTap: () => c.setLanguage('en', context),
              ),

              if (saving) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing:
          selected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
