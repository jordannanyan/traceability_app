// To parse this JSON data, do
//
//     final getTrees = getTreesFromJson(jsonString);

import 'dart:convert';

GetTrees getTreesFromJson(String str) => GetTrees.fromJson(json.decode(str));
String getTreesToJson(GetTrees data) => json.encode(data.toJson());

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }
  return null;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.trim().isNotEmpty) {
    try { return DateTime.parse(v); } catch (_) { return null; }
  }
  return null;
}

class GetTrees {
  int? currentPage;
  List<Datum>? data;
  String? firstPageUrl;
  int? from;
  int? lastPage;
  String? lastPageUrl;
  List<Link>? links;
  dynamic nextPageUrl;
  String? path;
  int? perPage;
  dynamic prevPageUrl;
  int? to;
  int? total;

  GetTrees({
    this.currentPage,
    this.data,
    this.firstPageUrl,
    this.from,
    this.lastPage,
    this.lastPageUrl,
    this.links,
    this.nextPageUrl,
    this.path,
    this.perPage,
    this.prevPageUrl,
    this.to,
    this.total,
  });

  factory GetTrees.fromJson(Map<String, dynamic> json) => GetTrees(
        currentPage: _toInt(json["current_page"]),
        data: json["data"] == null
            ? []
            : List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
        firstPageUrl: json["first_page_url"]?.toString(),
        from: _toInt(json["from"]),
        lastPage: _toInt(json["last_page"]),
        lastPageUrl: json["last_page_url"]?.toString(),
        links: json["links"] == null
            ? []
            : List<Link>.from(json["links"].map((x) => Link.fromJson(x))),
        nextPageUrl: json["next_page_url"],
        path: json["path"]?.toString(),
        perPage: _toInt(json["per_page"]),
        prevPageUrl: json["prev_page_url"],
        to: _toInt(json["to"]),
        total: _toInt(json["total"]),
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "first_page_url": firstPageUrl,
        "from": from,
        "last_page": lastPage,
        "last_page_url": lastPageUrl,
        "links": links == null ? [] : List<dynamic>.from(links!.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
        "path": path,
        "per_page": perPage,
        "prev_page_url": prevPageUrl,
        "to": to,
        "total": total,
      };
}

class Datum {
  int? id;
  int? plotId;
  int? farmerId;
  String? treeName;
  String? species;
  DateTime? plantingDate;
  String? qrCode;
  String? photoPath;
  double? latitude;   // <- double?
  double? longitude;  // <- double?
  double? accuracyM;  // <- double?
  DateTime? createdAt;
  DateTime? updatedAt;
  String? photoUrl;
  Plot? plot;
  Farmer? farmer;
  LatestMonitoring? latestMonitoring;

  Datum({
    this.id,
    this.plotId,
    this.farmerId,
    this.treeName,
    this.species,
    this.plantingDate,
    this.qrCode,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.createdAt,
    this.updatedAt,
    this.photoUrl,
    this.plot,
    this.farmer,
    this.latestMonitoring,
  });

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: _toInt(json["id"]),
        plotId: _toInt(json["plot_id"]),
        farmerId: _toInt(json["farmer_id"]),
        treeName: json["tree_name"]?.toString(),
        species: json["species"]?.toString(),
        plantingDate: _toDate(json["planting_date"]),
        qrCode: json["qr_code"]?.toString(),
        photoPath: json["photo_path"]?.toString(),
        latitude: _toD(json["latitude"]),
        longitude: _toD(json["longitude"]),
        accuracyM: _toD(json["accuracy_m"]),
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
        photoUrl: json["photo_url"]?.toString(),
        plot: json["plot"] == null ? null : Plot.fromJson(json["plot"]),
        farmer: json["farmer"] == null ? null : Farmer.fromJson(json["farmer"]),
        latestMonitoring: json["latest_monitoring"] == null
            ? null
            : LatestMonitoring.fromJson(json["latest_monitoring"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "plot_id": plotId,
        "farmer_id": farmerId,
        "tree_name": treeName,
        "species": species,
        "planting_date": plantingDate?.toIso8601String(),
        "qr_code": qrCode,
        "photo_path": photoPath,
        "latitude": latitude,     // kirim numerik/null
        "longitude": longitude,   // kirim numerik/null
        "accuracy_m": accuracyM,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "photo_url": photoUrl,
        "plot": plot?.toJson(),
        "farmer": farmer?.toJson(),
        "latest_monitoring": latestMonitoring?.toJson(),
      };
}

class Farmer {
  int? id;
  String? farmerName;
  int? kthId;

  Farmer({this.id, this.farmerName, this.kthId});

  factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
        id: _toInt(json["id"]),
        farmerName: json["farmer_name"]?.toString(),
        kthId: _toInt(json["kth_id"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "farmer_name": farmerName,
        "kth_id": kthId,
      };
}

class LatestMonitoring {
  int? id;
  int? treeId;
  DateTime? measuredAt;
  double? circumferenceCm; // <- double?
  String? healthStatus;
  String? healthDesc;
  String? photoPath;
  double? latitude;        // <- double?
  double? longitude;       // <- double?
  double? accuracyM;       // <- double?
  int? recordedByKthId;
  DateTime? createdAt;
  DateTime? updatedAt;

  LatestMonitoring({
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
  });

  factory LatestMonitoring.fromJson(Map<String, dynamic> json) => LatestMonitoring(
        id: _toInt(json["id"]),
        treeId: _toInt(json["tree_id"]),
        measuredAt: _toDate(json["measured_at"]),
        circumferenceCm: _toD(json["circumference_cm"]),
        healthStatus: json["health_status"]?.toString(),
        healthDesc: json["health_desc"]?.toString(),
        photoPath: json["photo_path"]?.toString(),
        latitude: _toD(json["latitude"]),
        longitude: _toD(json["longitude"]),
        accuracyM: _toD(json["accuracy_m"]),
        recordedByKthId: _toInt(json["recorded_by_kth_id"]),
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
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
      };
}

class Plot {
  int? id;
  String? plotName;
  int? farmerId;
  double? latitude;   // <- double?
  double? longitude;  // <- double?

  Plot({this.id, this.plotName, this.farmerId, this.latitude, this.longitude});

  factory Plot.fromJson(Map<String, dynamic> json) => Plot(
        id: _toInt(json["id"]),
        plotName: json["plot_name"]?.toString(),
        farmerId: _toInt(json["farmer_id"]),
        latitude: _toD(json["latitude"]),
        longitude: _toD(json["longitude"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "plot_name": plotName,
        "farmer_id": farmerId,
        "latitude": latitude,
        "longitude": longitude,
      };
}

class Link {
  String? url;
  String? label;
  bool? active;

  Link({this.url, this.label, this.active});

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        url: json["url"]?.toString(),
        label: json["label"]?.toString(),
        active: json["active"] is bool ? json["active"] as bool : json["active"] == 1,
      );

  Map<String, dynamic> toJson() => {
        "url": url,
        "label": label,
        "active": active,
      };
}
