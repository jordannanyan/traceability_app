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
