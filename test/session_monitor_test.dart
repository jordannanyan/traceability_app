import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/models/api/session_monitor.dart';

/// Answers every request with a fixed status, the way the real clients see it:
/// `validateStatus: (_) => true` means even a 401 arrives as a normal response.
class _FixedStatusAdapter implements HttpClientAdapter {
  final int status;
  _FixedStatusAdapter(this.status);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', status, headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  });

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int status) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.test',
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = _FixedStatusAdapter(status);
  dio.interceptors.add(SessionMonitor.watchdog());
  return dio;
}

void main() {
  setUp(() => SessionMonitor.instance.reset());

  group('SessionMonitor.isSessionRejection', () {
    test('only 401 counts as a rejected session', () {
      expect(SessionMonitor.isSessionRejection(401), isTrue);
      expect(SessionMonitor.isSessionRejection(200), isFalse);
      expect(SessionMonitor.isSessionRejection(404), isFalse);
      expect(SessionMonitor.isSessionRejection(500), isFalse);
      expect(SessionMonitor.isSessionRejection(null), isFalse);
    });

    test(
      '403 is excluded — a forbidden endpoint must not log the user out',
      () => expect(SessionMonitor.isSessionRejection(403), isFalse),
    );
  });

  group('watchdog interceptor', () {
    test('raises the flag on a 401 that arrives as a normal response', () async {
      await _dioReturning(401).get<void>('/farmers');

      expect(SessionMonitor.instance.expired.value, isTrue);
    });

    test('leaves the flag down for 200, 404 and 500', () async {
      for (final status in [200, 404, 500]) {
        SessionMonitor.instance.reset();
        await _dioReturning(status).get<void>('/farmers');
        expect(
          SessionMonitor.instance.expired.value,
          isFalse,
          reason: 'status $status must not end the session',
        );
      }
    });

    test('notifies listeners exactly once until reset', () async {
      var notifications = 0;
      void listener() => notifications++;
      SessionMonitor.instance.expired.addListener(listener);
      addTearDown(
        () => SessionMonitor.instance.expired.removeListener(listener),
      );

      final dio = _dioReturning(401);
      await dio.get<void>('/farmers');
      await dio.get<void>('/plots');
      await dio.get<void>('/trees');

      expect(
        notifications,
        1,
        reason: 'a burst of rejected requests is one expiry, not three',
      );

      SessionMonitor.instance.reset();
      await dio.get<void>('/farmers');
      expect(notifications, 3, reason: 'reset (2) then raised again (3)');
    });
  });

  group('CachedResult', () {
    test('fresh data is neither stale nor worth warning about', () {
      const r = CachedResult<List<int>>.fresh([1, 2]);
      expect(r.isStale, isFalse);
      expect(r.needsWarning, isFalse);
      expect(r.data, [1, 2]);
    });

    test('being offline is stale but not a warning — it has its own banner', () {
      const r = CachedResult<List<int>>([1], RefreshOutcome.offlineCache);
      expect(r.isStale, isTrue);
      expect(r.needsWarning, isFalse);
    });

    test('a failed refresh while online must be surfaced', () {
      for (final outcome in [
        RefreshOutcome.refreshFailed,
        RefreshOutcome.unauthorized,
      ]) {
        final r = CachedResult<List<int>>(const [1], outcome);
        expect(r.isStale, isTrue);
        expect(r.needsWarning, isTrue, reason: '$outcome must warn the user');
      }
    });
  });
}
