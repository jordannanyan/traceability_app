import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/under_development.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';

/// Penjualan — **ditutup sementara**.
///
/// Endpoint `/selling/kth/:id` tidak ada di agro-api (404): penjualan kini
/// bagian dari alur baru purchasing → processing → selling dengan struktur
/// tabel yang berbeda. Layar ini dulu tetap menampilkan angka dari cache lama,
/// termasuk nilai rupiah transaksi, seolah masih berlaku.
///
/// `SellingController` dan widget grafik/daftar dibiarkan di repositori sebagai
/// bahan saat layar ini dibangun ulang.
class SellingScreen extends StatelessWidget {
  const SellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: Obx(
          () => Text(
            LanguageService.to.language.value == 'id' ? 'Penjualan' : 'Selling',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
        toolbarHeight: 44,
      ),
      body: Obx(
        () => UnderDevelopment(
          isID: LanguageService.to.language.value == 'id',
          featureName: LanguageService.to.language.value == 'id'
              ? 'penjualan'
              : 'selling',
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 0),
    );
  }
}
