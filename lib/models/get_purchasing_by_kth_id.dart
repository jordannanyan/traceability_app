// To parse this JSON data, do
//
//     final getPurchasingByKthId = getPurchasingByKthIdFromJson(jsonString);

import 'dart:convert';

GetPurchasingByKthId getPurchasingByKthIdFromJson(String str) =>
    GetPurchasingByKthId.fromJson(json.decode(str));

String getPurchasingByKthIdToJson(GetPurchasingByKthId data) =>
    json.encode(data.toJson());

class GetPurchasingByKthId {
  final String? status;
  final List<Datum> data;

  GetPurchasingByKthId({this.status, required this.data});

  factory GetPurchasingByKthId.fromJson(Map<String, dynamic> json) =>
      GetPurchasingByKthId(
        status: json["status"] as String? ?? json["STATUS"] as String?,
        data: (json["data"] as List<dynamic>? ?? const [])
            .map((x) => Datum.fromJson(x as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "data": data.map((x) => x.toJson()).toList(),
      };
}

class Datum {
  final int? id;
  final DateTime? date;
  final int? plotId;
  final int? warehouseId;
  final int? commoditiesId;
  /// quantity is decimal in DB but app often treats it as text → keep String?
  final String? quantity;
  final int? gradeId;
  final int? pricePerKg;
  final int? valuePurchased;
  final dynamic uploadProofValue;      // stored path or null
  final int? deduction;
  final dynamic uploadProofDeduction;  // stored path or null
  final int? netPayment;
  final dynamic uploadProofPayment;    // stored path or null
  final dynamic signatureImage;        // NEW: stored path or null (same pattern)
  final String? status;                // accepts 'status' or 'STATUS'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Plot? plot;
  final Warehouse? warehouse;
  final Commodity? commodity;
  final Commodity? grade;              // backend returns a small object; reusing Commodity shape

  Datum({
    this.id,
    this.date,
    this.plotId,
    this.warehouseId,
    this.commoditiesId,
    this.quantity,
    this.gradeId,
    this.pricePerKg,
    this.valuePurchased,
    this.uploadProofValue,
    this.deduction,
    this.uploadProofDeduction,
    this.netPayment,
    this.uploadProofPayment,
    this.signatureImage,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.plot,
    this.warehouse,
    this.commodity,
    this.grade,
  });

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: _toInt(json["id"]),
        date: _toDate(json["date"]),
        plotId: _toInt(json["plot_id"]),
        warehouseId: _toInt(json["warehouse_id"]),
        commoditiesId: _toInt(json["commodities_id"]),
        quantity: _toStringOrNull(json["quantity"]),
        gradeId: _toInt(json["grade_id"]),
        pricePerKg: _toInt(json["price_per_kg"]),
        valuePurchased: _toInt(json["value_purchased"]),
        uploadProofValue: json["upload_proof_value"],
        deduction: _toInt(json["deduction"]),
        uploadProofDeduction: json["upload_proof_deduction"],
        netPayment: _toInt(json["net_payment"]),
        uploadProofPayment: json["upload_proof_payment"],
        signatureImage: json["signature_image"], // <- path (string) or null
        status: _toStringOrNull(json["status"]) ?? _toStringOrNull(json["STATUS"]),
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
        plot: json["plot"] == null ? null : Plot.fromJson(json["plot"]),
        warehouse: json["warehouse"] == null ? null : Warehouse.fromJson(json["warehouse"]),
        commodity: json["commodity"] == null ? null : Commodity.fromJson(json["commodity"]),
        grade: json["grade"] == null ? null : Commodity.fromJson(json["grade"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "date": date == null
            ? null
            : "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
        "plot_id": plotId,
        "warehouse_id": warehouseId,
        "commodities_id": commoditiesId,
        "quantity": quantity,
        "grade_id": gradeId,
        "price_per_kg": pricePerKg,
        "value_purchased": valuePurchased,
        "upload_proof_value": uploadProofValue,
        "deduction": deduction,
        "upload_proof_deduction": uploadProofDeduction,
        "net_payment": netPayment,
        "upload_proof_payment": uploadProofPayment,
        "signature_image": signatureImage,
        // keep lower-case 'status' when sending back
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "plot": plot?.toJson(),
        "warehouse": warehouse?.toJson(),
        "commodity": commodity?.toJson(),
        "grade": grade?.toJson(),
      };
}

/* ---------- Shared tiny helpers (robust parsing) ---------- */

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

String? _toStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // Accept "yyyy-MM-dd" or ISO8601
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

/* ---------- Other models (unchanged) ---------- */

class Commodity {
  int? id;
  String? commoditiesName;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? gradeName;

  Commodity({
    this.id,
    this.commoditiesName,
    this.createdAt,
    this.updatedAt,
    this.gradeName,
  });

  factory Commodity.fromJson(Map<String, dynamic> json) => Commodity(
        id: _toInt(json["id"]),
        commoditiesName: _toStringOrNull(json["commodities_name"]),
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
        gradeName: _toStringOrNull(json["grade_name"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "commodities_name": commoditiesName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "grade_name": gradeName,
      };
}

class Plot {
  int? id;
  String? plotName;
  String? landArea;
  int? numberOfPlants;
  dynamic latitude;
  dynamic longitude;
  int? farmerId;
  dynamic polygon;
  DateTime? createdAt;
  DateTime? updatedAt;

  Plot({
    this.id,
    this.plotName,
    this.landArea,
    this.numberOfPlants,
    this.latitude,
    this.longitude,
    this.farmerId,
    this.polygon,
    this.createdAt,
    this.updatedAt,
  });

  factory Plot.fromJson(Map<String, dynamic> json) => Plot(
        id: _toInt(json["id"]),
        plotName: _toStringOrNull(json["plot_name"]),
        landArea: _toStringOrNull(json["land_area"]),
        numberOfPlants: _toInt(json["number_of_plants"]),
        latitude: json["latitude"],
        longitude: json["longitude"],
        farmerId: _toInt(json["farmer_id"]),
        polygon: json["polygon"],
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "plot_name": plotName,
        "land_area": landArea,
        "number_of_plants": numberOfPlants,
        "latitude": latitude,
        "longitude": longitude,
        "farmer_id": farmerId,
        "polygon": polygon,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}

class Warehouse {
  int? id;
  String? warehouseName;
  String? address;
  int? kthId;
  DateTime? createdAt;
  DateTime? updatedAt;

  Warehouse({
    this.id,
    this.warehouseName,
    this.address,
    this.kthId,
    this.createdAt,
    this.updatedAt,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: _toInt(json["id"]),
        warehouseName: _toStringOrNull(json["warehouse_name"]),
        address: _toStringOrNull(json["address"]),
        kthId: _toInt(json["kth_id"]),
        createdAt: _toDate(json["created_at"]),
        updatedAt: _toDate(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "warehouse_name": warehouseName,
        "address": address,
        "kth_id": kthId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
