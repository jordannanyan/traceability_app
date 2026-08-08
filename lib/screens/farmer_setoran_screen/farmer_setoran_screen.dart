import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/widgets/bottom_navigation_bar_widget.dart';
import 'package:traceability_app/screens/widgets/under_development.dart';
import 'package:traceability_app/services/language_service.dart';

/// Setoran petani — **ditutup sementara**.
///
/// Layar ini membaca `/purchasing/farmer/:id`, yang tidak ada lagi di agro-api
/// (404) karena pembelian pindah ke struktur baru. Selain daftarnya, tombol
/// verifikasi setoran juga ikut dinonaktifkan: memverifikasi baris berumur
/// berbulan-bulan dari cache berarti petani menyetujui angka yang belum tentu
/// masih berlaku.
///
/// `FarmerSetoranController` dan widget-widgetnya dibiarkan di repositori
/// sebagai bahan saat layar ini dibangun ulang.
class FarmerSetoranScreen extends StatelessWidget {
  const FarmerSetoranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            LanguageService.to.language.value == 'id' ? 'Setoran' : 'Deposits',
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(currentIndex: 1),
      body: Obx(() {
        final isID = LanguageService.to.language.value == 'id';
        return UnderDevelopment(
          isID: isID,
          featureName: isID ? 'setoran' : 'deposit',
          note: isID
              ? 'Menu ini sedang disesuaikan dengan struktur data baru '
                    '(pembelian, processing, dan penjualan). Untuk sementara, '
                    'rincian setoran dan verifikasinya dilakukan lewat pengurus '
                    'KTH atau sistem kantor.'
              : 'This menu is being reworked for the new data structure '
                    '(purchasing, processing and selling). For now, deposit '
                    'details and verification go through your KTH or the office '
                    'system.',
        );
      }),
    );
  }
}
