import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/under_development.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_text.dart';

// Kept for backwards-compatibility if registered in MaterialApp.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Pembelian — **ditutup sementara**.
///
/// Pembelian, processing dan penjualan sudah pindah ke struktur database baru,
/// dan endpoint yang dipakai layar ini (`/purchasing/kth/:id`) tidak ada lagi
/// di agro-api — jawabannya 404. Layar lamanya masih bisa tampil karena membaca
/// cache, tetapi itu justru berbahaya: angka transaksi berbulan-bulan lalu
/// terlihat seolah data hari ini. Jadi isinya diganti keterangan jujur, dan
/// tidak ada lagi permintaan ke server dari sini.
///
/// `PurchasingController` beserta widget grafik/kartu sengaja ditinggalkan di
/// repositori sebagai bahan saat layar ini dibangun ulang mengikuti struktur
/// yang baru.
class PurchasingScreen extends StatelessWidget {
  const PurchasingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        title: Obx(
          () => Text(
            LanguageService.to.language.value == 'id'
                ? 'Pembelian'
                : 'Purchasing',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
        ),
      ),
      body: Obx(
        () => UnderDevelopment(
          isID: LanguageService.to.language.value == 'id',
          featureName: LanguageService.to.language.value == 'id'
              ? 'pembelian'
              : 'purchasing',
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 1),
    );
  }
}
