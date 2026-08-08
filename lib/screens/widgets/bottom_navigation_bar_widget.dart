import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/screens/home_kth_screen/home_kth_screen.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen.dart';
import 'package:traceability_app/screens/kth_setting_screen/kth_setting_screen.dart';
import 'package:traceability_app/screens/home_farmer_screen/home_farmer_screen.dart';
import 'package:traceability_app/screens/farmer_setoran_screen/farmer_setoran_screen.dart';
import 'package:traceability_app/screens/farmer_setting_screen/farmer_setting_screen.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';

class BottomNavigationBarWidget extends StatefulWidget {
  final int currentIndex;
  const BottomNavigationBarWidget({super.key, required this.currentIndex});

  @override
  State<BottomNavigationBarWidget> createState() =>
      _BottomNavigationBarWidgetState();
}

class _BottomNavigationBarWidgetState
    extends State<BottomNavigationBarWidget> {
  String loginAs = 'petani';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      loginAs = prefs.getString('login_as') ?? 'petani';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SizedBox.shrink();

    return Obx(() {
      final bool isID = LanguageService.to.language.value == 'id';
      return _buildBar(isID);
    });
  }

  Widget _buildBar(bool isID) {
    late final List<Widget> pages;
    late final List<BottomNavigationBarItem> items;

    if (loginAs == 'kth') {
      pages = const [
        HomeKthScreen(),
        PurchasingScreen(),
        KthSettingScreen(),
      ];

      items = [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_filled),
          label: isID ? 'Beranda' : 'Home',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.receipt_long_outlined),
          activeIcon: const Icon(Icons.receipt_long),
          label: isID ? 'Pembelian' : 'Purchasing',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: isID ? 'Pengaturan' : 'Settings',
        ),
      ];
    } else {
      pages = const [
        HomeFarmerScreen(),
        FarmerSetoranScreen(),
        FarmerSettingScreen(),
      ];

      items = [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_filled),
          label: isID ? 'Beranda' : 'Home',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.receipt_long_outlined),
          activeIcon: const Icon(Icons.receipt_long),
          label: isID ? 'Setoran' : 'Deposits',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: isID ? 'Pengaturan' : 'Settings',
        ),
      ];
    }

    // Clamp to valid range in case a screen passes an old index
    final safeIndex = widget.currentIndex.clamp(0, pages.length - 1);

    return Theme(
      data: Theme.of(context).copyWith(canvasColor: ThemeColor.white),
      child: BottomNavigationBar(
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: ThemeColor.darkestGreen,
        unselectedItemColor: ThemeColor.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        currentIndex: safeIndex,
        onTap: (index) {
          if (index == safeIndex) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => pages[index]),
          );
        },
        items: items,
      ),
    );
  }
}
