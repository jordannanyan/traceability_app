// To parse this JSON data, do
//
//     final pengepulModel = pengepulModelFromJson(jsonString);

import 'dart:convert';

PengepulModel pengepulModelFromJson(String str) => PengepulModel.fromJson(json.decode(str));

String pengepulModelToJson(PengepulModel data) => json.encode(data.toJson());

class PengepulModel {
    int? id;
    String? name;
    String? username;
    String? password;
    DateTime? createdAt;
    DateTime? updatedAt;

    PengepulModel({
        this.id,
        this.name,
        this.username,
        this.password,
        this.createdAt,
        this.updatedAt,
    });

    factory PengepulModel.fromJson(Map<String, dynamic> json) {
        // agro-api wraps the record as { data: {...} } and names the field
        // `kth_name` (not `name`). Unwrap + map so the KTH profile isn't blank.
        final m = (json["data"] is Map)
            ? Map<String, dynamic>.from(json["data"] as Map)
            : json;
        return PengepulModel(
            id: m["id"],
            name: m["name"] ?? m["kth_name"],
            username: m["username"],
            password: m["password"],
            createdAt: m["created_at"] == null ? null : DateTime.tryParse(m["created_at"].toString()),
            updatedAt: m["updated_at"] == null ? null : DateTime.tryParse(m["updated_at"].toString()),
        );
    }

    Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "username": username,
        "password": password,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
