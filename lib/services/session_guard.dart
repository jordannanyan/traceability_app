import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/session_monitor.dart';
import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/app_tokens.dart';

/// Takes the user back to login once the server has rejected the session.
///
/// Wraps the whole app (see `main.dart`) so it works from any screen. Before
/// this, only the two settings screens noticed a 401; every list screen quietly
/// served its cache, so an expired token looked like "the data never updates"
/// rather than "you are logged out".
///
/// **Queued offline work is preserved.** The existing logout paths call
/// `prefs.clear()`, which also wipes the outboxes — anything recorded in the
/// field but not yet uploaded would be destroyed. Here only the session keys
/// are removed, so a re-login can still push whatever is waiting.
class SessionGuard extends StatefulWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    SessionMonitor.instance.expired.addListener(_onExpiredChanged);
  }

  @override
  void dispose() {
    SessionMonitor.instance.expired.removeListener(_onExpiredChanged);
    super.dispose();
  }

  void _onExpiredChanged() {
    if (!SessionMonitor.instance.expired.value) return;
    if (_handling) return;
    _handling = true;
    // The notification arrives mid-request; wait for the frame so navigation
    // and the snackbar happen on a settled tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => _forceRelogin());
  }

  static const _loginRoutes = {'/login-koperasi', '/login-petani'};

  Future<void> _forceRelogin() async {
    // Requests already in flight when the session died keep arriving with 401s.
    // Once the user is on a login screen there is nothing left to do, and
    // re-navigating would stack duplicate snackbars over the form.
    if (_loginRoutes.contains(Get.currentRoute)) {
      SessionMonitor.instance.reset();
      _handling = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final loginAs = prefs.getString('login_as') ?? 'petani';

    // Session keys only — caches and outboxes stay put.
    await prefs.remove('token');
    await prefs.setBool('login', false);

    final isID = LanguageService.to.language.value == 'id';
    final route = loginAs == 'kth' ? '/login-koperasi' : '/login-petani';

    Get.offAllNamed<void>(route);

    // Get.snackbar rather than ScaffoldMessenger: this fires from a route
    // transition, where there is no reliable Scaffold context to hang on to.
    Get.snackbar(
      isID ? 'Sesi berakhir' : 'Session ended',
      isID
          ? 'Silakan masuk lagi untuk melanjutkan.'
          : 'Please log in again to continue.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(Insets.md),
    );

    // Re-arm for the next session.
    SessionMonitor.instance.reset();
    _handling = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
