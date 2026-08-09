import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/offline_tasks.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';

String _row({
  required String id,
  required String method,
  required String endpoint,
  int? entityId,
  Map<String, dynamic> body = const {},
  required int ts,
}) => jsonEncode({
  'id': id,
  'method': method,
  'endpoint': endpoint,
  'body': body,
  'entity_id': entityId,
  'ts': ts,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mengumpulkan antrean dari beberapa modul, terbaru di atas', () async {
    SharedPreferences.setMockInitialValues({
      'outbox_plot_v2': <String>[
        _row(
          id: '1',
          method: 'POST',
          endpoint: '/plots',
          body: {'plot_name': 'SJ99'},
          ts: 100,
        ),
      ],
      'outbox_tree_crud_v3': <String>[
        _row(
          id: '2',
          method: 'POST',
          endpoint: '/trees/7',
          entityId: 7,
          ts: 300,
        ),
      ],
      'outbox_warehouse_v1': <String>[
        _row(
          id: '3',
          method: 'DELETE',
          endpoint: '/warehouse/2',
          entityId: 2,
          ts: 200,
        ),
      ],
    });

    final tasks = await OfflineTaskCenter.all();

    expect(tasks.map((t) => t.module).toList(), [
      OfflineModule.tree,
      OfflineModule.warehouse,
      OfflineModule.plot,
    ], reason: 'urut dari yang paling baru diantre');

    expect(tasks.map((t) => t.kind).toList(), [
      PendingOpKind.update,
      PendingOpKind.delete,
      PendingOpKind.create,
    ]);
  });

  test('judul dan penjelas baris terbaca manusia', () async {
    SharedPreferences.setMockInitialValues({
      'outbox_plot_v2': <String>[
        _row(
          id: '1',
          method: 'POST',
          endpoint: '/plots',
          body: {'plot_name': 'SJ133134'},
          ts: 1,
        ),
      ],
    });

    final task = (await OfflineTaskCenter.all()).single;

    expect(task.title(true), 'Lahan baru');
    expect(task.title(false), 'New Plots');
    expect(task.detail(), 'SJ133134');
  });

  test('pembelian dan penjualan ditandai tidak boleh dikirim', () async {
    SharedPreferences.setMockInitialValues({
      'outbox_purch_crud_v1': <String>[
        _row(id: '1', method: 'POST', endpoint: '/purchasing', ts: 1),
      ],
      'outbox_selling_v1': <String>[
        _row(id: '2', method: 'POST', endpoint: '/selling', ts: 2),
      ],
      'outbox_tree_crud_v3': <String>[
        _row(id: '3', method: 'POST', endpoint: '/trees', ts: 3),
      ],
    });

    final tasks = await OfflineTaskCenter.all();

    expect(tasks.where((t) => t.canSync).length, 1);
    expect(
      tasks.where((t) => !t.canSync).map((t) => t.module).toSet(),
      {OfflineModule.purchasing, OfflineModule.selling},
      reason: 'antrean bentuk lama tidak boleh terdorong ke struktur baru',
    );
  });

  test('tanpa antrean, hasilnya kosong (bukan error)', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await OfflineTaskCenter.all(), isEmpty);
  });

  group('persentase unggah', () {
    // Rumus yang dipakai kartu di atas halaman. Diuji terpisah dari UI karena
    // titik rawannya matematika, bukan tata letak: dihitung terhadap jumlah
    // saat sesi unggah dimulai, bukan terhadap sisa antrean — kalau dibanding
    // sisa antrean, angkanya selalu 100% dan tidak pernah bergerak.
    int percent({required int batchTotal, required int batchDone,
        required int syncableLeft}) {
      if (batchTotal == 0) return syncableLeft == 0 ? 100 : 0;
      return ((batchDone / batchTotal).clamp(0.0, 1.0) * 100).round();
    }

    test('antrean kosong tanpa sesi unggah = 100%', () {
      expect(percent(batchTotal: 0, batchDone: 0, syncableLeft: 0), 100);
    });

    test('ada antrean tapi belum diunggah = 0%', () {
      expect(percent(batchTotal: 0, batchDone: 0, syncableLeft: 7), 0);
    });

    test('sebagian terkirim menunjukkan kemajuan sebenarnya', () {
      expect(percent(batchTotal: 8, batchDone: 2, syncableLeft: 6), 25);
      expect(percent(batchTotal: 3, batchDone: 1, syncableLeft: 2), 33);
    });

    test('semua terkirim = 100%', () {
      expect(percent(batchTotal: 5, batchDone: 5, syncableLeft: 0), 100);
    });
  });
}
