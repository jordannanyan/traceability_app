// To parse this JSON data, do
//
//     final getKthById = getKthByIdFromJson(jsonString);

import 'dart:convert';

GetKthById getKthByIdFromJson(String str) => GetKthById.fromJson(json.decode(str));

String getKthByIdToJson(GetKthById data) => json.encode(data.toJson());

class GetKthById {
    String? message;
    Data? data;

    GetKthById({
        this.message,
        this.data,
    });

    factory GetKthById.fromJson(Map<String, dynamic> json) => GetKthById(
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
    String? kthName;
    String? address;
    String? regency;
    String? partnershipPeriod;
    int? entitiesId;
    String? username;
    String? password;
    DateTime? createdAt;
    DateTime? updatedAt;
    Entity? entity;

    Data({
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
        this.entity,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
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
        entity: json["entity"] == null ? null : Entity.fromJson(json["entity"]),
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
        "entity": entity?.toJson(),
    };
}

class Entity {
    int? id;
    String? entitiesName;
    String? location;
    String? username;
    String? password;
    DateTime? createdAt;
    DateTime? updatedAt;

    Entity({
        this.id,
        this.entitiesName,
        this.location,
        this.username,
        this.password,
        this.createdAt,
        this.updatedAt,
    });

    factory Entity.fromJson(Map<String, dynamic> json) => Entity(
        id: json["id"],
        entitiesName: json["entities_name"],
        location: json["location"],
        username: json["username"],
        password: json["password"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "entities_name": entitiesName,
        "location": location,
        "username": username,
        "password": password,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
