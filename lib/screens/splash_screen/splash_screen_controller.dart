import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/screens/home_farmer_screen/home_farmer_screen.dart';
import 'package:traceability_app/screens/home_kth_screen/home_kth_screen.dart';
import 'package:traceability_app/screens/login_screen/login_petani_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_upsert_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('login') ?? false;

    if (loggedIn) {
      final loginAs = prefs.getString('login_as');
      _goToHome(loginAs);
      final resumedTree = await _maybeResumeTreeCapture(prefs);
      if (!resumedTree) await _maybeResumePolygonCapture(prefs);
    } else {
      await Future.delayed(const Duration(seconds: 2));
      Get.offAll(() => const LoginPetaniScreen());
    }
  }

  /// If the app was cold-restarted because Android destroyed the activity while
  /// the tree-photo camera was open, reopen the add/edit-tree screen so the
  /// captured photo (via ImagePicker.retrieveLostData) and GPS are recovered
  /// instead of being silently dropped on the home screen.
  Future<bool> _maybeResumeTreeCapture(SharedPreferences prefs) async {
    final pending = prefs.getBool(TreeUpsertController.kPendingTreeCaptureKey) ?? false;
    if (!pending) return false;
    await prefs.remove(TreeUpsertController.kPendingTreeCaptureKey);

    final args = <String, dynamic>{
      'treeId': prefs.getInt(TreeUpsertController.kPtcTreeIdKey),
      'plotId': prefs.getInt(TreeUpsertController.kPtcPlotIdKey),
      'farmerId': prefs.getInt(TreeUpsertController.kPtcFarmerIdKey),
      'kthId': prefs.getInt(TreeUpsertController.kPtcKthIdKey),
    };
    // Push on top of the home screen that _goToHome just placed.
    Get.toNamed('/tree_upsert', arguments: args);
    return true;
  }

  /// Same idea for the polygon editor: reopen it after a camera-kill so the
  /// in-progress points + photos (persisted snapshot) and the recovered photo
  /// are restored instead of being lost on the home screen.
  Future<bool> _maybeResumePolygonCapture(SharedPreferences prefs) async {
    final pending = prefs.getBool(KthPolygonController.kPendingPolygonCaptureKey) ?? false;
    if (!pending) return false;
    // Leave the snapshot for the controller to consume; just reopen the screen.
    Get.toNamed('/kth_polygon', arguments: {'__resumePolygon': true});
    return true;
  }

  void _goToHome(String? loginAs) {
    Widget home;
    if (loginAs == 'kth') {
      home = const HomeKthScreen();
    } else if (loginAs == 'petani') {
      home = const HomeFarmerScreen();
    } else {
      home = const LoginPetaniScreen();
    }
    Get.offAll(() => home);
  }
}
