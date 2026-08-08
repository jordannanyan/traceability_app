// To parse this JSON data, do
//
//     final getSellingByKthId = getSellingByKthIdFromJson(jsonString);

import 'dart:convert';

GetSellingByKthId getSellingByKthIdFromJson(String str) => GetSellingByKthId.fromJson(json.decode(str));

String getSellingByKthIdToJson(GetSellingByKthId data) => json.encode(data.toJson());

class GetSellingByKthId {
    String? status;
    List<Datum>? data;

    GetSellingByKthId({
        this.status,
        this.data,
    });

    factory GetSellingByKthId.fromJson(Map<String, dynamic> json) => GetSellingByKthId(
        status: json["status"],
        data: json["data"] == null ? [] : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "status": status,
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    };
}

class Datum {
    int? id;
    DateTime? date;
    int? warehouseId;
    int? offtakerId;
    int? commoditiesId;
    int? gradeId;
    int? quantity;
    String? pricePerKg;
    String? totalPrice;
    String? taxesOrDeductions;
    String? totalNetSales;
    dynamic uploadInvoice;
    dynamic uploadDo;
    DateTime? createdAt;
    DateTime? updatedAt;
    Warehouse? warehouse;
    OffTaker? offTaker;
    Commodity? commodity;
    Commodity? grade;

    Datum({
        this.id,
        this.date,
        this.warehouseId,
        this.offtakerId,
        this.commoditiesId,
        this.gradeId,
        this.quantity,
        this.pricePerKg,
        this.totalPrice,
        this.taxesOrDeductions,
        this.totalNetSales,
        this.uploadInvoice,
        this.uploadDo,
        this.createdAt,
        this.updatedAt,
        this.warehouse,
        this.offTaker,
        this.commodity,
        this.grade,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        date: json["date"] == null ? null : DateTime.parse(json["date"]),
        warehouseId: json["warehouse_id"],
        offtakerId: json["offtaker_id"],
        commoditiesId: json["commodities_id"],
        gradeId: json["grade_id"],
        quantity: json["quantity"],
        pricePerKg: json["price_per_kg"],
        totalPrice: json["total_price"],
        taxesOrDeductions: json["taxes_or_deductions"],
        totalNetSales: json["total_net_sales"],
        uploadInvoice: json["upload_invoice"],
        uploadDo: json["upload_do"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        warehouse: json["warehouse"] == null ? null : Warehouse.fromJson(json["warehouse"]),
        offTaker: json["offTaker"] == null ? null : OffTaker.fromJson(json["offTaker"]),
        commodity: json["commodity"] == null ? null : Commodity.fromJson(json["commodity"]),
        grade: json["grade"] == null ? null : Commodity.fromJson(json["grade"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "date": "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
        "warehouse_id": warehouseId,
        "offtaker_id": offtakerId,
        "commodities_id": commoditiesId,
        "grade_id": gradeId,
        "quantity": quantity,
        "price_per_kg": pricePerKg,
        "total_price": totalPrice,
        "taxes_or_deductions": taxesOrDeductions,
        "total_net_sales": totalNetSales,
        "upload_invoice": uploadInvoice,
        "upload_do": uploadDo,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "warehouse": warehouse?.toJson(),
        "offTaker": offTaker?.toJson(),
        "commodity": commodity?.toJson(),
        "grade": grade?.toJson(),
    };
}

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
        id: json["id"],
        commoditiesName: json["commodities_name"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        gradeName: json["grade_name"],
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "commodities_name": commoditiesName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "grade_name": gradeName,
    };
}

class OffTaker {
    int? id;
    String? offtakerName;
    String? location;
    int? entitiesId;
    DateTime? createdAt;
    DateTime? updatedAt;

    OffTaker({
        this.id,
        this.offtakerName,
        this.location,
        this.entitiesId,
        this.createdAt,
        this.updatedAt,
    });

    factory OffTaker.fromJson(Map<String, dynamic> json) => OffTaker(
        id: json["id"],
        offtakerName: json["offtaker_name"],
        location: json["location"],
        entitiesId: json["entities_id"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "offtaker_name": offtakerName,
        "location": location,
        "entities_id": entitiesId,
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
        id: json["id"],
        warehouseName: json["warehouse_name"],
        address: json["address"],
        kthId: json["kth_id"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
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
