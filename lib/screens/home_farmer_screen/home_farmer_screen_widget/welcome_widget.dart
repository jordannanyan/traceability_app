import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/themes/theme_color.dart';
// import 'package:traceability_app/gamification/gamify_mock.dart'; // DIHAPUS

class WelcomeWidget extends StatefulWidget {
  const WelcomeWidget({super.key});

  @override
  State<WelcomeWidget> createState() => _WelcomeWidgetState();
}

class _WelcomeWidgetState extends State<WelcomeWidget> {
  String _farmerName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    if (!mounted) return;
    setState(() {
      _farmerName = name;
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
                _farmerName.isNotEmpty
                    ? (isID ? 'Halo $_farmerName' : 'Hello $_farmerName')
                    : (isID ? 'Halo Petani' : 'Hello Farmer'),
                style: ThemeTextStyle.textStyleFirstBold,
              ),
              const SizedBox(height: 10),
              Text(
                isID
                    ? 'Selamat Datang Ke Aplikasi Petani'
                    : 'Welcome to the Farmer App',
                style: ThemeTextStyle.textStyleThird,
              ),
              // (Info poin/gamification DIHAPUS)
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).popAndPushNamed('/settings-farmer');
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
