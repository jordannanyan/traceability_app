import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traceability_app/models/api/refresh_outcome.dart';

/// Semua pembaca cached-first (plot, pohon, pembelian, gudang, penjualan,
/// monitoring, petani) lewat helper ini, jadi cukup di sini klasifikasinya
/// diuji sekali.
Response<dynamic> _response(int status) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/x'),
  statusCode: status,
);

Future<CachedResult<String>> _run({
  required bool online,
  int? status,
  Object? requestThrows,
  String? cached,
  bool cacheThrows = false,
}) => readCachedFirst<String>(
  isOnline: () async => online,
  request: () async {
    if (requestThrows != null) throw requestThrows;
    return _response(status!);
  },
  parseAndCache: (_) async => 'segar',
  readCache: () async {
    if (cacheThrows) throw StateError('cache rusak');
    return cached;
  },
  emptyValue: (outcome) => 'kosong:${outcome.name}',
);

void main() {
  test('server menjawab 200 -> data segar', () async {
    final r = await _run(online: true, status: 200, cached: 'lama');
    expect(r.data, 'segar');
    expect(r.outcome, RefreshOutcome.fresh);
    expect(r.needsWarning, isFalse);
  });

  test('offline -> pakai cache, tanpa peringatan', () async {
    final r = await _run(online: false, cached: 'lama');
    expect(r.data, 'lama');
    expect(r.outcome, RefreshOutcome.offlineCache);
    expect(r.needsWarning, isFalse, reason: 'offline sudah punya banner sendiri');
  });

  test('401 -> cache lama + ditandai sesi ditolak', () async {
    final r = await _run(online: true, status: 401, cached: 'lama');
    expect(r.data, 'lama', reason: 'data tetap tampil supaya tidak kosong');
    expect(r.outcome, RefreshOutcome.unauthorized);
    expect(r.needsWarning, isTrue, reason: 'inilah bug yang dulu diam saja');
  });

  test('500 dan error jaringan -> gagal refresh, bukan sesi ditolak', () async {
    final byStatus = await _run(online: true, status: 500, cached: 'lama');
    expect(byStatus.outcome, RefreshOutcome.refreshFailed);

    final byThrow = await _run(
      online: true,
      requestThrows: Exception('timeout'),
      cached: 'lama',
    );
    expect(byThrow.outcome, RefreshOutcome.refreshFailed);
  });

  test('tidak ada cache -> nilai kosong, alasannya tetap terbawa', () async {
    final r = await _run(online: true, status: 401);
    expect(r.data, 'kosong:unauthorized');
    expect(r.outcome, RefreshOutcome.unauthorized);
  });

  test('cache rusak tidak menjatuhkan layar', () async {
    final r = await _run(online: false, cacheThrows: true);
    expect(r.data, 'kosong:offlineCache');
    expect(r.outcome, RefreshOutcome.offlineCache);
  });
}
