import 'package:dio/dio.dart';

/// Classifies a failed outbox push into DROP vs KEEP.
///
/// Returns `true` when the item should be **dropped** — a client error that
/// will never succeed on retry and would otherwise block the whole outbox
/// forever (the queue is processed in order, so one permanently-failing item
/// stalls everything behind it).
///
/// Returns `false` (keep for a later retry) for anything recoverable:
/// - network / timeout errors (a `DioException` with no response),
/// - 5xx server errors,
/// - 401 / 403 — auth problems, recoverable after the token is refreshed,
/// - 408 / 429 — request timeout / rate limiting,
/// - any non-HTTP error (e.g. a briefly missing local file).
///
/// Dropped (poison): other 4xx — 400 / 404 / 405 / 409 / 422 / … — i.e. a
/// malformed or rejected request that cannot succeed as-is.
///
/// NOTE: this only classifies correctly if HTTP error responses actually surface
/// as a [DioException]. The API clients use `validateStatus: (_) => true`, so a
/// non-2xx response does NOT raise a DioException on its own — `_throwHttp` must
/// convert it into one (with the response attached) for this to work.
bool isPoisonOutboxError(Object e) {
  if (e is! DioException) return false;
  final code = e.response?.statusCode;
  if (code == null || code < 400 || code >= 500) return false;
  if (code == 401 || code == 403 || code == 408 || code == 429) return false;
  return true;
}
