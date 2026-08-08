// To parse this JSON data, do
//
//     final editWarehouse = editWarehouseFromJson(jsonString);

import 'dart:convert';

EditWarehouse editWarehouseFromJson(String str) => EditWarehouse.fromJson(json.decode(str));

String editWarehouseToJson(EditWarehouse data) => json.encode(data.toJson());

class EditWarehouse {
    String? message;
    Data? data;

    EditWarehouse({
        this.message,
        this.data,
    });

    factory EditWarehouse.fromJson(Map<String, dynamic> json) => EditWarehouse(
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
    };
}

class Data {
    int? id;
    String? warehouseName;
    String? address;
    int? kthId;
    DateTime? createdAt;
    DateTime? updatedAt;

    Data({
        this.id,
        this.warehouseName,
        this.address,
        this.kthId,
        this.createdAt,
        this.updatedAt,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
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
