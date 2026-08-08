import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:traceability_app/screens/widgets/gps_loading_dialog.dart';
import 'package:traceability_app/services/gps_sampler.dart';
import 'package:traceability_app/services/language_service.dart';

/// Runs the shared GPS sampling flow (same one used for tree capture) and
/// writes the resulting coordinates into [latCtrl] / [lngCtrl].
///
/// Returns `true` when a position was captured and the fields were filled.
///
/// Also guards the two most common "koordinat selalu sama" causes on real
/// devices: location services being off, and the app only holding the
/// **approximate** (reduced) location permission introduced in Android 12,
/// which returns a coarse, near-constant position that barely moves. In those
/// cases it surfaces an actionable snackbar (with a shortcut to the relevant
/// settings) instead of silently returning the same value.
Future<bool> captureCoordinatesInto(
  BuildContext context, {
  required TextEditingController latCtrl,
  required TextEditingController lngCtrl,
}) async {
  final isID = LanguageService.to.isId;

  // 1) Location service (GPS) must be enabled.
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isID
            ? 'Layanan lokasi (GPS) mati. Nyalakan lalu coba lagi.'
            : 'Location services are off. Turn them on and try again.'),
        action: SnackBarAction(
          label: isID ? 'Setelan' : 'Settings',
          onPressed: Geolocator.openLocationSettings,
        ),
      ));
    }
    return false;
  }

  // Serialize the permission prompt before opening the progress dialog so
  // Android does not reject the request (matches the tree-capture flow).
  await ensureLocationPermission();
  if (!context.mounted) return false;

  // 2) Detect "approximate" (reduced) location — the usual reason coordinates
  // barely change on a real device. We still capture, but warn clearly.
  bool reduced = false;
  try {
    reduced =
        (await Geolocator.getLocationAccuracy()) == LocationAccuracyStatus.reduced;
  } catch (_) {}
  if (!context.mounted) return false;

  final session = startGpsSampling();
  final result = await showGpsLoadingDialog(context, session: session);
  final pos = result.position;

  if (pos != null) {
    latCtrl.text = pos.latitude.toStringAsFixed(7);
    lngCtrl.text = pos.longitude.toStringAsFixed(7);
  }

  // Always confirm what was actually captured (value + accuracy), plus any
  // warning. A large accuracy and/or the "approximate" note explains an
  // unchanging coordinate: it's the location source, not a UI/binding issue.
  // A mocked/fake-GPS provider reports a fixed point (often with a fake, very
  // good accuracy) that never moves — the #1 cause of "±1 m but always the same
  // coordinate" on a real device.
  final mocked = pos?.isMocked ?? false;

  if (context.mounted) {
    final warn = gpsResultMessage(result);
    final buf = StringBuffer();
    if (pos != null) {
      buf.write(
          '${isID ? 'Koordinat' : 'Coordinates'}: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
      if (pos.accuracy > 0) buf.write(' (±${pos.accuracy.toStringAsFixed(1)} m)');
      if (warn != null) buf.write('\n$warn');
    } else {
      buf.write(warn ??
          (isID ? 'Lokasi tidak tersedia.' : 'Location unavailable.'));
    }
    if (mocked) {
      buf.write(isID
          ? '\n⚠ Lokasi TIRUAN (mock) terdeteksi — itu sebabnya selalu sama. Matikan aplikasi lokasi palsu / "Pilih aplikasi lokasi tiruan" di Opsi Pengembang.'
          : '\n⚠ MOCK location detected — that is why it never changes. Disable the fake-GPS app / "Select mock location app" in Developer options.');
    } else if (reduced) {
      buf.write(isID
          ? '\n⚠ Izin lokasi masih "Perkiraan" — nilai kasar & nyaris sama walau berpindah. Aktifkan "Lokasi tepat".'
          : '\n⚠ Location permission is "Approximate" — coarse and near-constant even when you move. Enable "Precise location".');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: (mocked || reduced) ? 7 : 4),
      content: Text(buf.toString()),
      action: reduced && !mocked
          ? SnackBarAction(
              label: isID ? 'Izin' : 'Fix',
              onPressed: Geolocator.openAppSettings,
            )
          : null,
    ));
  }

  return pos != null;
}
