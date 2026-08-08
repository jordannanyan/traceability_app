import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Notices when the server has stopped accepting this device's session.
///
/// Every API client sets `validateStatus: (_) => true`, so a `401` is not an
/// error to Dio — it flows through the normal path and, in the cached-first
/// readers, lands in the "just use the cache" branch. The result was an app
/// that silently froze in time: the token expires (7 days), every request is
/// rejected, and each screen keeps serving month-old cached rows with no error
/// anywhere. Pulling to refresh changed nothing, because the refresh *was*
/// running — it was being turned away.
///
/// This watchdog is attached to every client, so a rejected session is noticed
/// wherever it happens, not only on the two screens that used to check for it.
/// [SessionGuard] listens and takes the user back to the login screen.
class SessionMonitor {
  SessionMonitor._();

  static final SessionMonitor instance = SessionMonitor._();

  /// Flips to true the first time the server rejects the session. Listeners
  /// react once; [reset] arms it again after the user logs back in.
  final ValueNotifier<bool> expired = ValueNotifier<bool>(false);

  void reportUnauthorized() {
    if (!expired.value) expired.value = true;
  }

  void reset() {
    if (expired.value) expired.value = false;
  }

  /// Only 401 means "this session is no longer valid".
  ///
  /// 403 is deliberately excluded: it means the server understood who you are
  /// and refused anyway, so logging out would not help and would throw away a
  /// working session over one forbidden endpoint.
  static bool isSessionRejection(int? statusCode) => statusCode == 401;

  /// Attach to a Dio instance to report auth failures from any endpoint.
  static Interceptor watchdog() => InterceptorsWrapper(
    onResponse: (response, handler) {
      if (isSessionRejection(response.statusCode)) {
        instance.reportUnauthorized();
      }
      handler.next(response);
    },
    onError: (e, handler) {
      if (isSessionRejection(e.response?.statusCode)) {
        instance.reportUnauthorized();
      }
      handler.next(e);
    },
  );
}
