import 'package:flutter/material.dart';

import 'package:traceability_app/screens/splash_screen/splash_screen_controller.dart';
import 'package:traceability_app/utils/controller_registry.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ControllerRegistry.lazyPut(() => SplashController());

    return Scaffold(
      body: Center(
        child: Image.asset('assets/logo.png', width: 180, height: 180),
      ),
    );
  }
}
