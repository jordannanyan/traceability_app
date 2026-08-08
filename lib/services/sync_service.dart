import 'package:traceability_app/models/api/farmer_api.dart';
import 'package:traceability_app/models/api/plot_api.dart';
import 'package:traceability_app/models/api/purchasing_api.dart';
import 'package:traceability_app/models/api/selling_api.dart';
import 'package:traceability_app/models/api/tree_api.dart';
import 'package:traceability_app/models/api/tree_monitoring_api.dart';
import 'package:traceability_app/models/api/warehouse_api.dart';

/// Central offline-sync bootstrap.
///
/// Each API keeps its own outbox + connectivity listener, but those listeners
/// only fire on future connectivity *changes* and are only registered when the
/// screen that uses that API is opened. That left a gap: data queued offline in
/// module A never synced if the user reconnected before opening module A's
/// screen (e.g. app closed offline, reopened already online).
///
/// [startAll] registers every API's listener once, right after login (from the
/// KTH/farmer home screens). Because each `startAutoSyncListener` now also
/// flushes its outbox immediately on first start, this guarantees every pending
/// outbox is pushed as soon as the app opens online — regardless of which
/// screen the user visits. The per-API `_syncListenerStarted` guard makes this
/// idempotent, so calling it from both home screens is safe.
class SyncService {
  static Future<void> startAll() async {
    await Future.wait([
      PlotApi.startAutoSyncListener(),
      TreeApi.startAutoSyncListener(),
      TreeMonitoringApi.startAutoSyncListener(),
      PurchasingApi.startAutoSyncListener(),
      SellingApi.startAutoSyncListener(),
      WarehouseApi.startAutoSyncListener(),
      FarmerApi.startAutoSyncListener(),
    ]);
  }
}
