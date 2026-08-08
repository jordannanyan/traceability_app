import 'package:get/get.dart';

/// Safe helpers for registering GetX controllers from inside `build()`.
///
/// Calling `Get.put(MyController())` directly in `build()` re-creates the
/// controller on every rebuild, leaking listeners and resetting state. These
/// helpers register once and reuse the existing instance on subsequent builds.
class ControllerRegistry {
  ControllerRegistry._();

  /// Returns the existing instance if registered, otherwise creates one via
  /// [builder] and registers it. Use this inside `build()` instead of
  /// `Get.put(...)` to avoid re-instantiation on every rebuild.
  static T lazyPut<T>(T Function() builder, {String? tag}) {
    if (Get.isRegistered<T>(tag: tag)) {
      return Get.find<T>(tag: tag);
    }
    return Get.put<T>(builder(), tag: tag);
  }
}
