import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/themes/theme_color.dart';

class WelcomeWidget extends StatefulWidget {
  const WelcomeWidget({super.key});

  @override
  State<WelcomeWidget> createState() => _WelcomeWidgetState();
}

class _WelcomeWidgetState extends State<WelcomeWidget> {
  String _kthName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    setState(() {
      _kthName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isID = LanguageService.to.language.value == 'id';
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kthName.isNotEmpty
                      ? (isID ? 'Halo $_kthName' : 'Hello $_kthName')
                      : (isID ? 'Halo Partner' : 'Hello Partner'),
                  style: ThemeTextStyle.textStyleFirstBold,
                ),
                const SizedBox(height: 10),
                Text(
                  isID
                      ? 'Selamat Datang Ke Aplikasi Partners'
                      : 'Welcome to the Partners App',
                  style: ThemeTextStyle.textStyleThird,
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).popAndPushNamed('/settings-kth');
              },
              child: Icon(
                Icons.settings,
                color: ThemeColor.darkestGreen,
              ),
            ),
          ],
        ),
      );
    });
  }
}
