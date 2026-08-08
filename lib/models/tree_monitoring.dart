// lib/models/tree_monitoring.dart
import 'dart:convert';

List<TreeMonitoring> treeMonitoringListFromJson(String str) =>
    List<TreeMonitoring>.from(json.decode(str)["data"].map((x) => TreeMonitoring.fromJson(x)));

/// Untuk response paginate Laravel: simpan apa adanya jika perlu.
MonitoringPage monitoringPageFromJson(String str) =>
    MonitoringPage.fromJson(json.decode(str));

String monitoringPageToJson(MonitoringPage data) => json.encode(data.toJson());

class MonitoringPage {
  final int? currentPage;
  final List<TreeMonitoring> data;
  final int? perPage;
  final int? total;

  MonitoringPage({this.currentPage, required this.data, this.perPage, this.total});

  factory MonitoringPage.fromJson(Map<String, dynamic> j) => MonitoringPage(
        currentPage: j["current_page"],
        data: (j["data"] is List)
            ? List<TreeMonitoring>.from(j["data"].map((x) => TreeMonitoring.fromJson(x)))
            : <TreeMonitoring>[],
        perPage: j["per_page"] is int ? j["per_page"] : int.tryParse("${j["per_page"] ?? ""}"),
        total: j["total"] is int ? j["total"] : int.tryParse("${j["total"] ?? ""}"),
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "per_page": perPage,
        "total": total,
      };
}

class TreeMonitoring {
  final int? id;
  final int? treeId;
  final DateTime? measuredAt;
  final String? circumferenceCm; // disimpan string biar aman dengan server
  final String? healthStatus;    // 'Sehat' | 'Tidak Sehat' | 'Mati'
  final String? healthDesc;
  final String? photoPath;       // <- inilah yang dipakai
  final String? latitude;
  final String? longitude;
  final String? accuracyM;
  final int? recordedByKthId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? photoUrl;        // server boleh kembalikan ini; kl ada, biarkan

  TreeMonitoring({
    this.id,
    this.treeId,
    this.measuredAt,
    this.circumferenceCm,
    this.healthStatus,
    this.healthDesc,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.recordedByKthId,
    this.createdAt,
    this.updatedAt,
    this.photoUrl,
  });

  factory TreeMonitoring.fromJson(Map<String, dynamic> j) => TreeMonitoring(
        id: j["id"],
        treeId: j["tree_id"],
        measuredAt: j["measured_at"] == null ? null : DateTime.parse(j["measured_at"]),
        circumferenceCm: j["circumference_cm"]?.toString(),
        healthStatus: j["health_status"],
        healthDesc: j["health_desc"],
        photoPath: j["photo_path"],
        latitude: j["latitude"]?.toString(),
        longitude: j["longitude"]?.toString(),
        accuracyM: j["accuracy_m"]?.toString(),
        recordedByKthId: j["recorded_by_kth_id"],
        createdAt: j["created_at"] == null ? null : DateTime.parse(j["created_at"]),
        updatedAt: j["updated_at"] == null ? null : DateTime.parse(j["updated_at"]),
        photoUrl: j["photo_url"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "tree_id": treeId,
        "measured_at": measuredAt?.toIso8601String(),
        "circumference_cm": circumferenceCm,
        "health_status": healthStatus,
        "health_desc": healthDesc,
        "photo_path": photoPath,
        "latitude": latitude,
        "longitude": longitude,
        "accuracy_m": accuracyM,
        "recorded_by_kth_id": recordedByKthId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "photo_url": photoUrl,
      };
}
