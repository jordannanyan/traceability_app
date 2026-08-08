import 'package:dio/dio.dart';

import 'package:traceability_app/models/api/session_monitor.dart';

/// Why a cached-first read returned what it returned.
///
/// The offline-first readers always hand back *something* — fresh data when the
/// server answered, otherwise whatever was cached. That is right for the field,
/// but it used to be indistinguishable from success: a screen showing month-old
/// rows looked exactly like a screen with nothing new. The outcome travels with
/// the data so the UI can say which of the two it is.
enum RefreshOutcome {
  /// The server answered and the cache was refreshed with it.
  fresh,

  /// No connectivity, so the stored copy was used. Expected in the field —
  /// screens already show their own offline banner for this.
  offlineCache,

  /// Online, but the refresh failed (network hiccup, timeout, 5xx). The stored
  /// copy was used instead, and the user should be told it may be out of date.
  refreshFailed,

  /// Online, but the server rejected the session (401). The stored copy was
  /// used; re-logging in is the only way to see current data.
  unauthorized,
}

/// A cached-first payload plus the reason it looks the way it does.
class CachedResult<T> {
  final T data;
  final RefreshOutcome outcome;

  const CachedResult(this.data, this.outcome);

  const CachedResult.fresh(this.data) : outcome = RefreshOutcome.fresh;

  /// True when the data on screen is not known to match the server.
  bool get isStale => outcome != RefreshOutcome.fresh;

  /// True when the user should be warned — being offline is normal and already
  /// signposted, a failed refresh while online is not.
  bool get needsWarning =>
      outcome == RefreshOutcome.refreshFailed ||
      outcome == RefreshOutcome.unauthorized;
}

/// The one cached-first read shared by every API client.
///
/// Each client used to spell out the same four branches by hand — fresh, no
/// connection, bad status, thrown error — and each of them ended in a bare
/// `return cached`, which is how a rejected session turned into a screen that
/// silently never updated. Routing them all through here means the
/// classification is written once and is the same everywhere.
///
/// [request] runs inside the try, so an auth helper that throws on a missing
/// token is treated as a failed refresh rather than crashing the screen.
/// [emptyValue] supplies the "nothing cached either" result; it receives the
/// outcome so callers can keep their existing status strings.
Future<CachedResult<T>> readCachedFirst<T>({
  required Future<bool> Function() isOnline,
  required Future<Response<dynamic>> Function() request,
  required Future<T> Function(Response<dynamic> resp) parseAndCache,
  required Future<T?> Function() readCache,
  required T Function(RefreshOutcome outcome) emptyValue,
}) async {
  Future<CachedResult<T>> fallback(RefreshOutcome outcome) async {
    try {
      final cached = await readCache();
      return CachedResult(cached ?? emptyValue(outcome), outcome);
    } catch (_) {
      // A corrupt cache entry must not take the screen down with it.
      return CachedResult(emptyValue(outcome), outcome);
    }
  }

  if (!await isOnline()) return fallback(RefreshOutcome.offlineCache);

  try {
    final resp = await request();
    if (resp.statusCode == 200) {
      return CachedResult.fresh(await parseAndCache(resp));
    }
    // Clients set `validateStatus: (_) => true`, so a rejected session arrives
    // here as an ordinary response rather than an exception.
    return fallback(
      SessionMonitor.isSessionRejection(resp.statusCode)
          ? RefreshOutcome.unauthorized
          : RefreshOutcome.refreshFailed,
    );
  } catch (_) {
    return fallback(RefreshOutcome.refreshFailed);
  }
}
