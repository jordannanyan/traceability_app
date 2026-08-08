import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/screens/add_purchasing_screen/add_purchasing_screen.dart';
import 'package:traceability_app/screens/edit_warehouse_screen/edit_warehouse_screen.dart';
import 'package:traceability_app/screens/edit_plot_screen/edit_plot_screen.dart';
import 'package:traceability_app/screens/edit_purchasing_screen/edit_purchasing_screen.dart';
import 'package:traceability_app/screens/farmer_setoran_screen/farmer_setoran_screen.dart';
import 'package:traceability_app/screens/farmer_setting_screen/farmer_setting_screen.dart';
import 'package:traceability_app/screens/home_farmer_screen/home_farmer_screen.dart';
import 'package:traceability_app/screens/home_kth_screen/home_kth_screen.dart';
import 'package:traceability_app/screens/gudang_screen/gudang_screen.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_add_plot_screen.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_edit_plot_screen.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_screen.dart';
import 'package:traceability_app/screens/lahan_screen/lahan_screen.dart';
import 'package:traceability_app/screens/language_screen/language_screen.dart';
import 'package:traceability_app/screens/login_screen/login_koperasi_screen.dart';
import 'package:traceability_app/screens/login_screen/login_petani_screen.dart';
import 'package:traceability_app/screens/privacy_policies_screen/privacy_policies_screen.dart';
import 'package:traceability_app/screens/profile_screen/profile_screen.dart';
import 'package:traceability_app/screens/purchasing_screen/purchasing_screen.dart';
import 'package:traceability_app/screens/kth_setting_screen/kth_setting_screen.dart';
import 'package:traceability_app/screens/saprodi_screen/saprodi_screen.dart';
import 'package:traceability_app/screens/selling_screen/selling_screen.dart';
import 'package:traceability_app/screens/splash_screen/splash_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_upsert_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await Get.putAsync<LanguageService>(
    () => LanguageService().init(),
    permanent: true,
  );
  runApp(const MyApp());
}

// Routes that need to read login_as to decide which screen to show
class HomeWrapper extends StatelessWidget {
  const HomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final loginAs = snapshot.data!.getString('login_as') ?? 'petani';
        return loginAs == 'kth'
            ? const HomeKthScreen()
            : const HomeFarmerScreen();
      },
    );
  }
}

class SettingWrapper extends StatelessWidget {
  const SettingWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final loginAs = snapshot.data!.getString('login_as') ?? 'petani';
        return loginAs == 'kth'
            ? const KthSettingScreen()
            : const FarmerSettingScreen();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Petani',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeColor.darkestGreen,
          primary: ThemeColor.darkestGreen,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        appBarTheme: const AppBarTheme(
          backgroundColor: ThemeColor.darkestGreen,
          foregroundColor: ThemeColor.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: ThemeColor.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Clamp text scale globally
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 0.95,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child!,
        );
      },

      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login-petani': (_) => const LoginPetaniScreen(),
        '/login-koperasi': (_) => const LoginKoperasiScreen(),
        '/home': (_) => const HomeWrapper(),
        '/gudang': (_) => const GudangScreen(),
        '/edit_warehouse': (_) => const EditWarehouseScreen(),

        // ===== FARMER =====
        '/lahan': (_) => const PlotScreen(),
        '/edit_plot': (_) => const EditPlotScreen(),

        // ===== KTH PLOTS =====
        '/kth_plot': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map) ? args : <dynamic, dynamic>{};
          return KthPlotScreen(
            farmerId: (map['farmerId'] as int?) ?? 0,
            farmerName: map['farmerName']?.toString(),
          );
        },
        '/kth_add_plot': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map) ? args : <dynamic, dynamic>{};
          return KthAddPlotScreen(
            farmerId: (map['farmerId'] as int?) ?? 0,
            farmerName: map['farmerName']?.toString(),
            initialPolygonWkt: map['polygonWkt']?.toString(),
          );
        },
        '/kth_edit_plot': (_) => const KthEditPlotScreen(),
        '/kth_polygon': (_) => const KthPolygonScreen(),

        // Reopened on cold-restart after Android kills the activity while the
        // camera is open (see TreeUpsertController capture-marker + Splash resume).
        '/tree_upsert': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map) ? args : <dynamic, dynamic>{};
          return TreeUpsertScreen(
            treeId: map['treeId'] as int?,
            kthId: map['kthId'] as int?,
            farmerId: map['farmerId'] as int?,
            plotId: map['plotId'] as int?,
          );
        },

        // ===== OTHERS =====
        '/penjualan': (_) => const SellingScreen(),
        '/setoran': (_) => const PurchasingScreen(),
        '/edit-purchasing': (_) => const EditPurchasingScreen(),
        '/add-Pembelian': (_) => const AddPurchasingScreen(),
        '/pembelian-petani': (_) => const FarmerSetoranScreen(),
        '/saprodi': (_) => const SaprodiScreen(),
        '/settings-farmer': (_) => const FarmerSettingScreen(),
        '/settings-kth': (_) => const KthSettingScreen(),
        '/language': (_) => const LanguageScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/privacy-policy': (_) => const PrivacyPolicyScreen(),
      },
    );
  }
}
