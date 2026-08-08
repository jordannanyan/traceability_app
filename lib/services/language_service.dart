import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the app's current language.
///
/// Registered as a permanent service in main() so every controller and widget
/// can react to changes instantly without restarting the app.
class LanguageService extends GetxService {
  static const _prefsKey = 'language';
  static const _defaultCode = 'id';

  final RxString language = _defaultCode.obs;

  /// Self-healing accessor: if a careless `Get.deleteAll(force: true)` killed
  /// the permanent registration, recreate it on demand so callers never crash.
  static LanguageService get to {
    if (Get.isRegistered<LanguageService>()) {
      return Get.find<LanguageService>();
    }
    final svc = Get.put<LanguageService>(LanguageService(), permanent: true);
    svc.init();
    return svc;
  }

  bool get isId => language.value == 'id';

  Future<LanguageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    language.value = prefs.getString(_prefsKey) ?? _defaultCode;
    return this;
  }

  Future<void> setLanguage(String code) async {
    if (code == language.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    language.value = code;
  }
}
