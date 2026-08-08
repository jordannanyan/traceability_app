import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

enum GpsFailureReason {
  serviceDisabled,
  permissionDenied,
  noSamples,
  cancelled,
}

class GpsProgress {
  final int sampleCount;
  final double? bestRawAccuracy;
  final double? effectiveAccuracy;
  final Duration elapsed;
  final Duration remaining;
  final bool meetsTarget;

  const GpsProgress({
    required this.sampleCount,
    required this.bestRawAccuracy,
    required this.effectiveAccuracy,
    required this.elapsed,
    required this.remaining,
    required this.meetsTarget,
  });
}

class GpsSampleResult {
  final Position? position;
  final int sampleCount;
  final double? bestRawAccuracy;
  final double? effectiveAccuracy;
  final bool meetsTarget;
  final GpsFailureReason? failureReason;

  const GpsSampleResult({
    required this.position,
    required this.sampleCount,
    required this.bestRawAccuracy,
    required this.effectiveAccuracy,
    required this.meetsTarget,
    required this.failureReason,
  });
}

class GpsSamplingSession {
  final Stream<GpsProgress> progress;
  final Future<GpsSampleResult> result;
  final void Function() cancel;
  final void Function() acceptNow;

  const GpsSamplingSession({
    required this.progress,
    required this.result,
    required this.cancel,
    required this.acceptNow,
  });
}

Future<bool> ensureLocationPermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) {
    p = await Geolocator.requestPermission();
  }
  return p != LocationPermission.denied &&
      p != LocationPermission.deniedForever;
}

GpsSamplingSession startGpsSampling({
  Duration warmup = const Duration(seconds: 2),
  Duration maxWindow = const Duration(seconds: 120),
  double targetEffectiveAccuracy = 5,
  double maxRawAccuracy = 50,
  int minSamples = 8,
  Duration progressTick = const Duration(milliseconds: 500),
}) {
  final progressCtl = StreamController<GpsProgress>.broadcast();
  final resultCompleter = Completer<GpsSampleResult>();

  final samples = <Position>[];
  StreamSubscription<Position>? sub;
  Timer? hardTimer;
  Timer? tickTimer;
  bool finished = false;
  final start = DateTime.now();
  final warmupEnd = start.add(warmup);
  final hardEnd = start.add(warmup + maxWindow);

  GpsProgress buildProgress() {
    final elapsed = DateTime.now().difference(start);
    final remaining = hardEnd.difference(DateTime.now());
    double? bestRaw;
    double? effective;
    bool meets = false;
    if (samples.isNotEmpty) {
      bestRaw = samples
          .map((p) => p.accuracy)
          .where((a) => a > 0)
          .fold<double>(double.infinity, math.min);
      if (bestRaw == double.infinity) bestRaw = null;
      effective = _effectiveAccuracy(samples);
      meets = effective != null && effective <= targetEffectiveAccuracy;
    }
    return GpsProgress(
      sampleCount: samples.length,
      bestRawAccuracy: bestRaw,
      effectiveAccuracy: effective,
      elapsed: elapsed,
      remaining: remaining.isNegative ? Duration.zero : remaining,
      meetsTarget: meets,
    );
  }

  void emit() {
    if (progressCtl.isClosed) return;
    progressCtl.add(buildProgress());
  }

  Future<void> finishWith(
    Position? pos, {
    GpsFailureReason? failure,
  }) async {
    if (finished) return;
    finished = true;
    hardTimer?.cancel();
    tickTimer?.cancel();
    await sub?.cancel();
    final cleaned = _rejectOutliers(samples);
    final list = cleaned.length >= 3 ? cleaned : samples;
    final effective = list.isEmpty ? null : _effectiveAccuracy(list);
    final bestRaw = list.isEmpty
        ? null
        : list
            .map((p) => p.accuracy)
            .where((a) => a > 0)
            .fold<double>(double.infinity, math.min);
    final meets =
        effective != null && effective <= targetEffectiveAccuracy;
    final result = GpsSampleResult(
      position: pos,
      sampleCount: samples.length,
      bestRawAccuracy: (bestRaw == null || bestRaw == double.infinity)
          ? null
          : bestRaw,
      effectiveAccuracy: effective,
      meetsTarget: meets,
      failureReason: failure,
    );
    if (!resultCompleter.isCompleted) resultCompleter.complete(result);
    if (!progressCtl.isClosed) {
      await progressCtl.close();
    }
  }

  Future<void> finalizeFromSamples({
    required GpsFailureReason? fallbackReason,
  }) async {
    if (samples.isEmpty) {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (p.accuracy > 0) {
          await finishWith(p);
          return;
        }
      } catch (_) {}
      await finishWith(null,
          failure: fallbackReason ?? GpsFailureReason.noSamples);
      return;
    }

    final cleaned = _rejectOutliers(samples);
    final list = cleaned.length >= 3 ? cleaned : samples;
    final avg = _weightedAverage(list);
    await finishWith(avg);
  }

  Future<void> begin() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await finishWith(null,
            failure: GpsFailureReason.serviceDisabled);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        await finishWith(null,
            failure: GpsFailureReason.permissionDenied);
        return;
      }

      emit();
      tickTimer = Timer.periodic(progressTick, (_) => emit());

      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      );

      sub = stream.listen(
        (p) {
          if (finished) return;
          final now = DateTime.now();
          if (now.isBefore(warmupEnd)) return;
          if (p.accuracy <= 0 || p.accuracy > maxRawAccuracy) return;
          samples.add(p);
          emit();

          if (samples.length >= minSamples) {
            final eff = _effectiveAccuracy(samples);
            if (eff != null && eff <= targetEffectiveAccuracy) {
              finalizeFromSamples(fallbackReason: null);
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      hardTimer = Timer(warmup + maxWindow, () {
        finalizeFromSamples(fallbackReason: null);
      });
    } catch (_) {
      await finishWith(null, failure: GpsFailureReason.noSamples);
    }
  }

  void cancel() {
    if (finished) return;
    if (samples.isEmpty) {
      finishWith(null, failure: GpsFailureReason.cancelled);
    } else {
      finalizeFromSamples(fallbackReason: GpsFailureReason.cancelled);
    }
  }

  void acceptNow() {
    if (finished) return;
    finalizeFromSamples(fallbackReason: null);
  }

  begin();

  return GpsSamplingSession(
    progress: progressCtl.stream,
    result: resultCompleter.future,
    cancel: cancel,
    acceptNow: acceptNow,
  );
}

double? _effectiveAccuracy(List<Position> samples) {
  if (samples.isEmpty) return null;
  double sumW = 0;
  for (final p in samples) {
    final acc = p.accuracy <= 0 ? 1.0 : p.accuracy;
    sumW += 1.0 / (acc * acc);
  }
  if (sumW <= 0) return null;
  return 1.0 / math.sqrt(sumW);
}

List<Position> _rejectOutliers(List<Position> samples) {
  if (samples.length < 4) return samples;

  final cLat =
      samples.map((p) => p.latitude).reduce((a, b) => a + b) /
          samples.length;
  final cLng =
      samples.map((p) => p.longitude).reduce((a, b) => a + b) /
          samples.length;

  const metersPerDegLat = 111320.0;
  final metersPerDegLng =
      metersPerDegLat * math.cos(cLat * math.pi / 180.0);

  final distances = samples.map((p) {
    final dy = (p.latitude - cLat) * metersPerDegLat;
    final dx = (p.longitude - cLng) * metersPerDegLng;
    return math.sqrt(dx * dx + dy * dy);
  }).toList();

  final mean = distances.reduce((a, b) => a + b) / distances.length;
  final variance = distances
          .map((d) => (d - mean) * (d - mean))
          .reduce((a, b) => a + b) /
      distances.length;
  final stddev = math.sqrt(variance);
  final threshold = mean + 2 * stddev;

  final kept = <Position>[];
  for (var i = 0; i < samples.length; i++) {
    if (distances[i] <= threshold) kept.add(samples[i]);
  }
  return kept;
}

Position _weightedAverage(List<Position> samples) {
  double sumW = 0;
  double sumLat = 0;
  double sumLng = 0;
  Position best = samples.first;
  for (final p in samples) {
    final acc = p.accuracy <= 0 ? 1.0 : p.accuracy;
    final w = 1.0 / (acc * acc);
    sumW += w;
    sumLat += p.latitude * w;
    sumLng += p.longitude * w;
    if (p.accuracy > 0 && p.accuracy < best.accuracy) best = p;
  }
  final effectiveAccuracy = 1.0 / math.sqrt(sumW);
  return Position(
    latitude: sumLat / sumW,
    longitude: sumLng / sumW,
    accuracy: effectiveAccuracy,
    altitude: best.altitude,
    altitudeAccuracy: best.altitudeAccuracy,
    heading: best.heading,
    headingAccuracy: best.headingAccuracy,
    speed: best.speed,
    speedAccuracy: best.speedAccuracy,
    timestamp: DateTime.now(),
    isMocked: best.isMocked,
    floor: best.floor,
  );
}
