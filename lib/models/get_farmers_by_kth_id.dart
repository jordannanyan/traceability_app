// To parse this JSON data, do
//
//     final getFarmerByKthId = getFarmerByKthIdFromJson(jsonString);

import 'dart:convert';

List<GetFarmerByKthId> getFarmerByKthIdFromJson(String str) => List<GetFarmerByKthId>.from(json.decode(str).map((x) => GetFarmerByKthId.fromJson(x)));

String getFarmerByKthIdToJson(List<GetFarmerByKthId> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class GetFarmerByKthId {
    int? id;
    String? farmerName;
    int? numberOfChildren;
    dynamic dateOfBirth;
    int? previousIncome;
    String? address;
    int? kthId;
    String? password;
    String? noHp;
    String? nik;
    dynamic noRek;
    dynamic foto;
    int? preFinance;
    DateTime? createdAt;
    DateTime? updatedAt;
    Kth? kth;

    GetFarmerByKthId({
        this.id,
        this.farmerName,
        this.numberOfChildren,
        this.dateOfBirth,
        this.previousIncome,
        this.address,
        this.kthId,
        this.password,
        this.noHp,
        this.nik,
        this.noRek,
        this.foto,
        this.preFinance,
        this.createdAt,
        this.updatedAt,
        this.kth,
    });

    factory GetFarmerByKthId.fromJson(Map<String, dynamic> json) => GetFarmerByKthId(
        id: json["id"],
        farmerName: json["farmer_name"],
        numberOfChildren: json["number_of_children"],
        dateOfBirth: json["date_of_birth"],
        previousIncome: json["previous_income"],
        address: json["address"],
        kthId: json["kth_id"],
        password: json["password"],
        noHp: json["no_hp"],
        nik: json["nik"],
        noRek: json["no_rek"],
        foto: json["foto"],
        preFinance: json["pre_finance"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        kth: json["kth"] == null ? null : Kth.fromJson(json["kth"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "farmer_name": farmerName,
        "number_of_children": numberOfChildren,
        "date_of_birth": dateOfBirth,
        "previous_income": previousIncome,
        "address": address,
        "kth_id": kthId,
        "password": password,
        "no_hp": noHp,
        "nik": nik,
        "no_rek": noRek,
        "foto": foto,
        "pre_finance": preFinance,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "kth": kth?.toJson(),
    };
}

class Kth {
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
        this.entity,
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
