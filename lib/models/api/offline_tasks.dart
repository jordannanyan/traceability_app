import 'package:traceability_app/models/api/farmer_api.dart';
import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/api/selling_api.dart';
import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/models/api/tree_monitoring_api.dart';
import 'package:traceability_app/models/api/warehouse_api.dart';

/// Modul yang punya antrean offline sendiri.
enum OfflineModule { plot, tree, treeMonitoring, warehouse, farmer, purchasing, selling }

extension OfflineModuleLabel on OfflineModule {
  String label(bool isID) {
    switch (this) {
      case OfflineModule.plot:
        return isID ? 'Lahan' : 'Plots';
      case OfflineModule.tree:
        return isID ? 'Pohon' : 'Trees';
      case OfflineModule.treeMonitoring:
        return isID ? 'Monitoring Pohon' : 'Tree monitoring';
      case OfflineModule.warehouse:
        return isID ? 'Gudang' : 'Warehouse';
      case OfflineModule.farmer:
        return isID ? 'Data Petani' : 'Farmer data';
      case OfflineModule.purchasing:
        return isID ? 'Pembelian' : 'Purchasing';
      case OfflineModule.selling:
        return isID ? 'Penjualan' : 'Selling';
    }
  }

  /// Pembelian dan penjualan tidak ikut dikirim: layarnya ditutup sementara
  /// struktur datanya dibangun ulang, dan antrean lamanya dibuat dengan bentuk
  /// data yang sudah tidak berlaku. Ditampilkan supaya tidak ada yang hilang
  /// diam-diam, tapi tidak pernah didorong ke server.
  bool get canSync =>
      this != OfflineModule.purchasing && this != OfflineModule.selling;
}

/// Satu pekerjaan yang menunggu terkirim, apa pun modulnya.
class OfflineTask {
  final OfflineModule module;
  final PendingOp op;

  const OfflineTask(this.module, this.op);

  PendingOpKind get kind => op.kind;
  DateTime get queuedAt => op.queuedAt;
  bool get canSync => module.canSync;

  /// Judul baris: apa yang terjadi pada data apa.
  String title(bool isID) {
    final what = module.label(isID);
    switch (op.kind) {
      case PendingOpKind.create:
        return isID ? '$what baru' : 'New $what';
      case PendingOpKind.update:
        return isID ? 'Perubahan $what' : '$what change';
      case PendingOpKind.delete:
        return isID ? 'Penghapusan $what' : '$what deletion';
    }
  }

  /// Penjelas baris: nama datanya kalau bisa ditebak dari payload, kalau tidak
  /// nomor datanya. Nama yang dipakai adalah field yang memang dikirim ke
  /// server, jadi tidak perlu menebak-nebak bentuk khusus per modul.
  String? detail() {
    for (final key in const [
      'plot_name',
      'tree_name',
      'species',
      'warehouse_name',
      'farmer_name',
      'health_status',
    ]) {
      final v = op.body[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    if (op.entityId != null) return '#${op.entityId}';
    return null;
  }
}

/// Mengumpulkan seluruh antrean offline dari semua modul, dan mendorongnya.
///
/// Sebelum ini setiap modul hanya tahu antreannya sendiri: pengguna harus
/// membuka layar Pohon untuk tahu ada pohon tertunda, membuka layar Lahan untuk
/// tahu ada plot tertunda, dan seterusnya. Halaman Data Offline memakai kelas
/// ini untuk menjawab satu pertanyaan di satu tempat: apa saja yang belum
/// terkirim, dan berapa yang sudah.
class OfflineTaskCenter {
  const OfflineTaskCenter._();

  /// Semua pekerjaan tertunda, terbaru di atas.
  static Future<List<OfflineTask>> all() async {
    final results = await Future.wait([
      PlotApi.pendingOps(),
      TreeApi.pendingOps(),
      TreeMonitoringApi.pendingOps(),
      WarehouseApi.pendingOps(),
      FarmerApi.pendingOps(),
      PurchasingApi.pendingOps(),
      SellingApi.pendingOps(),
    ]);

    const modules = [
      OfflineModule.plot,
      OfflineModule.tree,
      OfflineModule.treeMonitoring,
      OfflineModule.warehouse,
      OfflineModule.farmer,
      OfflineModule.purchasing,
      OfflineModule.selling,
    ];

    final tasks = <OfflineTask>[];
    for (var i = 0; i < modules.length; i++) {
      for (final op in results[i]) {
        tasks.add(OfflineTask(modules[i], op));
      }
    }

    tasks.sort((a, b) => b.op.ts.compareTo(a.op.ts));
    return tasks;
  }

  /// Mendorong antrean semua modul yang boleh dikirim.
  ///
  /// Tiap modul memakai push miliknya sendiri (lengkap dengan kunci antrean dan
  /// penanganan item bermasalah), jadi perilakunya sama persis dengan tombol
  /// Sync per layar — hanya dijalankan sekaligus.
  static Future<int> pushAll() async {
    var pushed = 0;
    for (final push in <Future<int> Function()>[
      () => PlotApi().pushPlotOutbox(),
      () => TreeApi().pushTreeOutbox(),
      () => TreeMonitoringApi().pushOutbox(),
      () => WarehouseApi().pushWarehouseOutbox(),
      () => FarmerApi().pushFarmerOutbox(),
    ]) {
      try {
        pushed += await push();
      } catch (_) {
        // Satu modul gagal tidak boleh menghentikan modul lain; sisanya tetap
        // terlihat di daftar dan bisa dicoba lagi.
      }
    }
    return pushed;
  }
}
