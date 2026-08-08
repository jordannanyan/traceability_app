// To parse this JSON data, do
//
//   final editPurchasing = editPurchasingFromJson(jsonString);

import 'dart:convert';

EditPurchasing editPurchasingFromJson(String str) =>
    EditPurchasing.fromJson(json.decode(str));

String editPurchasingToJson(EditPurchasing data) =>
    json.encode(data.toJson());

// ---------------- Helpers robust ----------------

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _asString(dynamic v) {
  if (v == null) return null;
  return v.toString();
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}

// =================================================

class EditPurchasing {
  String? message;
  Data? data;

  EditPurchasing({
    this.message,
    this.data,
  });

  factory EditPurchasing.fromJson(Map<String, dynamic> json) => EditPurchasing(
        message: _asString(json["message"]),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
      };
}

class Data {
  int? id;
  DateTime? date;
  int? plotId;
  int? warehouseId;
  int? commoditiesId;
  String? quantity;               // backend kadang string → biarkan string
  int? gradeId;
  int? pricePerKg;                // angka bisa datang sebagai string → _asInt
  int? valuePurchased;
  dynamic uploadProofValue;       // bisa URL string atau null
  int? deduction;
  dynamic uploadProofDeduction;
  int? netPayment;
  dynamic uploadProofPayment;

  // NEW: digital signature image (same storage style as other proofs)
  dynamic signatureImage;         // path/URL string or null

  // Ada dua kemungkinan kunci status dari backend:
  // - "STATUS" (uppercase)
  // - "status" (lowercase)
  // Kita simpan dua-duanya agar tidak bentrok.
  String? statusUpper;            // dari key "STATUS"
  String? statusLower;            // dari key "status"

  DateTime? createdAt;
  DateTime? updatedAt;

  Data({
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
    this.signatureImage,          // ← added
    this.statusUpper,
    this.statusLower,
    this.createdAt,
    this.updatedAt,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        id: _asInt(json["id"]),
        date: _asDate(json["date"]),
        plotId: _asInt(json["plot_id"]),
        warehouseId: _asInt(json["warehouse_id"]),
        commoditiesId: _asInt(json["commodities_id"]),
        quantity: _asString(json["quantity"]),
        gradeId: _asInt(json["grade_id"]),
        pricePerKg: _asInt(json["price_per_kg"]),
        valuePurchased: _asInt(json["value_purchased"]),
        uploadProofValue: json["upload_proof_value"],
        deduction: _asInt(json["deduction"]),
        uploadProofDeduction: json["upload_proof_deduction"],
        netPayment: _asInt(json["net_payment"]),
        uploadProofPayment: json["upload_proof_payment"],
        signatureImage: json["signature_image"],         // ← added
        statusUpper: _asString(json["STATUS"]),
        statusLower: _asString(json["status"]),
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        if (date != null)
          "date":
              "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
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
        "signature_image": signatureImage,               // ← added
        if (statusUpper != null) "STATUS": statusUpper,
        if (statusLower != null) "status": statusLower,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
