// To parse this JSON data, do
//
//     final addPurchasing = addPurchasingFromJson(jsonString);

import 'dart:convert';

AddPurchasing addPurchasingFromJson(String str) => AddPurchasing.fromJson(json.decode(str));

String addPurchasingToJson(AddPurchasing data) => json.encode(data.toJson());

class AddPurchasing {
    String? message;
    Data? data;

    AddPurchasing({
        this.message,
        this.data,
    });

    factory AddPurchasing.fromJson(Map<String, dynamic> json) => AddPurchasing(
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
    };
}

class Data {
    DateTime? date;
    String? plotId;
    String? warehouseId;
    String? commoditiesId;
    String? quantity;
    String? gradeId;
    String? pricePerKg;
    String? valuePurchased;
    String? uploadProofValue;
    String? deduction;
    String? uploadProofDeduction;
    String? netPayment;
    String? uploadProofPayment;
    DateTime? updatedAt;
    DateTime? createdAt;
    int? id;

    Data({
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
        this.updatedAt,
        this.createdAt,
        this.id,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
        date: json["date"] == null ? null : DateTime.parse(json["date"]),
        plotId: json["plot_id"],
        warehouseId: json["warehouse_id"],
        commoditiesId: json["commodities_id"],
        quantity: json["quantity"],
        gradeId: json["grade_id"],
        pricePerKg: json["price_per_kg"],
        valuePurchased: json["value_purchased"],
        uploadProofValue: json["upload_proof_value"],
        deduction: json["deduction"],
        uploadProofDeduction: json["upload_proof_deduction"],
        netPayment: json["net_payment"],
        uploadProofPayment: json["upload_proof_payment"],
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        id: json["id"],
    );

    Map<String, dynamic> toJson() => {
        "date": "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
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
        "updated_at": updatedAt?.toIso8601String(),
        "created_at": createdAt?.toIso8601String(),
        "id": id,
    };
}
