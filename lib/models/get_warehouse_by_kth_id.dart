// To parse this JSON data, do
//
//     final getWarehouseByKthId = getWarehouseByKthIdFromJson(jsonString);

import 'dart:convert';

GetWarehouseByKthId getWarehouseByKthIdFromJson(String str) => GetWarehouseByKthId.fromJson(json.decode(str));

String getWarehouseByKthIdToJson(GetWarehouseByKthId data) => json.encode(data.toJson());

class GetWarehouseByKthId {
    String? message;
    List<Datum>? data;

    GetWarehouseByKthId({
        this.message,
        this.data,
    });

    factory GetWarehouseByKthId.fromJson(Map<String, dynamic> json) => GetWarehouseByKthId(
        message: json["message"],
        data: json["data"] == null ? [] : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    };
}

class Datum {
    int? id;
    String? warehouseName;
    String? address;
    int? kthId;
    DateTime? createdAt;
    DateTime? updatedAt;
    Kth? kth;

    Datum({
        this.id,
        this.warehouseName,
        this.address,
        this.kthId,
        this.createdAt,
        this.updatedAt,
        this.kth,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        warehouseName: json["warehouse_name"],
        address: json["address"],
        kthId: json["kth_id"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        kth: json["kth"] == null ? null : Kth.fromJson(json["kth"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "warehouse_name": warehouseName,
        "address": address,
        "kth_id": kthId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "kth": kth?.toJson(),
    };
}

class Kth {
    int? id;
    String? kthName;
    dynamic address;
    String? regency;
    dynamic partnershipPeriod;
    int? entitiesId;
    String? username;
    String? password;
    DateTime? createdAt;
    DateTime? updatedAt;

    Kth({
        this.id,
        this.kthName,
        this.address,
        this.regency,
        this.partnershipPeriod,
        this.entitiesId,
        this.username,
        this.password,
        this.createdAt,
        this.updatedAt,
    });

    factory Kth.fromJson(Map<String, dynamic> json) => Kth(
        id: json["id"],
        kthName: json["kth_name"],
        address: json["address"],
        regency: json["regency"],
        partnershipPeriod: json["partnership_period"],
        entitiesId: json["entities_id"],
        username: json["username"],
        password: json["password"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "kth_name": kthName,
        "address": address,
        "regency": regency,
        "partnership_period": partnershipPeriod,
        "entities_id": entitiesId,
        "username": username,
        "password": password,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
