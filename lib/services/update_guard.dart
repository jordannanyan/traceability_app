import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:traceability_app/services/language_service.dart';
import 'package:traceability_app/themes/app_tokens.dart';
import 'package:traceability_app/themes/theme_color.dart';

/// Forces the user onto the newest Play Store release before using the app.
///
/// Wraps the whole app (see `main.dart`), next to [SessionGuard]. On launch and
/// every time the app returns to the foreground it asks Google Play whether a
/// newer version exists; if so it starts Play's *immediate* update — the
/// full-screen flow that downloads, installs and restarts the app.
///
/// Play lets the user back out of that flow, so a declined or failed update
/// leaves a blocking screen over the app with an "Update" button instead of
/// letting them carry on with the old version.
///
/// **Fails open.** No signal, a sideloaded/debug build (Play reports the app as
/// not owned), or any Play error lets the app run as normal — an offline-first
/// field app must never lock someone out in a plantation with no coverage. The
/// next foreground with a connection checks again.
///
/// **Queued offline work is safe.** An update replaces the APK only;
/// SharedPreferences (caches, outboxes, session) survive it, so whatever was
/// recorded offline is still pushed after the restart.
class UpdateGuard extends StatefulWidget {
  final Widget child;

  const UpdateGuard({super.key, required this.child});

  @override
  State<UpdateGuard> createState() => _UpdateGuardState();
}

class _UpdateGuardState extends State<UpdateGuard> with WidgetsBindingObserver {
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.fairventures.koperasi_app';

  /// In-app updates only exist on Android builds installed from Play.
  static final bool _supported = !kIsWeb && Platform.isAndroid && kReleaseMode;

  bool _mustUpdate = false;

  /// Play's update screen sits on top of ours; dismissing it fires another
  /// `resumed`. Without this guard that would start a second, overlapping flow.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable ||
          // An update the user already started (then left the app) must be
          // resumed, per Play's guidelines for immediate updates.
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress;

      if (!available) {
        _setMustUpdate(false);
        return;
      }

      _setMustUpdate(true);
      if (info.immediateUpdateAllowed) {
        await _runImmediateUpdate();
      }
    } catch (_) {
      // Offline, not installed from Play, Play services missing… fail open,
      // but keep the block if this session already knows an update exists.
    } finally {
      _busy = false;
    }
  }

  /// On success Play restarts the app itself, so only the non-success results
  /// ever come back here — the blocking screen stays up for those.
  Future<void> _runImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // Leave the blocking screen; its button offers the store page instead.
    }
  }

  Future<void> _onUpdatePressed() async {
    if (_busy) return;
    _busy = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        // Only a Play-side failure sends the user to the store page; a
        // declined update just leaves this screen up.
        if (result != AppUpdateResult.inAppUpdateFailed) return;
      }
    } catch (_) {
      // Fall through to the store page.
    } finally {
      _busy = false;
    }
    await launchUrl(
      Uri.parse(_playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  void _setMustUpdate(bool value) {
    if (!mounted || _mustUpdate == value) return;
    setState(() => _mustUpdate = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_mustUpdate) return widget.child;
    // Stacked over the navigator rather than pushed as a route, so the screens
    // underneath (and any half-filled form) are untouched if the check later
    // clears — e.g. Play stops offering the update.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(child: _UpdateRequiredScreen(onUpdate: _onUpdatePressed)),
      ],
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  final VoidCallback onUpdate;

  const _UpdateRequiredScreen({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isID = LanguageService.to.language.value == 'id';
    return Material(
      color: ThemeColor.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 120, height: 120),
              const SizedBox(height: Insets.xl),
              Text(
                isID ? 'Pembaruan diperlukan' : 'Update required',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Insets.md),
              Text(
                isID
                    ? 'Versi baru aplikasi sudah tersedia di Play Store. '
                        'Perbarui aplikasi untuk melanjutkan. '
                        'Data yang belum terkirim tetap aman.'
                    : 'A new version is available on the Play Store. '
                        'Update the app to continue. '
                        'Data waiting to sync is kept.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpdate,
                  child: Text(isID ? 'Perbarui sekarang' : 'Update now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
