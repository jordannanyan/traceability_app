// To parse this JSON data, do
//
//     final petaniModel = petaniModelFromJson(jsonString);

import 'dart:convert';

List<PetaniModel> petaniModelFromJson(String str) => List<PetaniModel>.from(json.decode(str).map((x) => PetaniModel.fromJson(x)));

String petaniModelToJson(List<PetaniModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class PetaniModel {
    int? id;
    String? name;
    String? noHp;
    String? password;
    String? noKtp;
    String? foto;
    String? location;
    double? surfaceAreaTotal;
    int? plantTotal;
    double? lastHarvestTotal;
    int? verified;
    DateTime? createdAt;
    DateTime? updatedAt;

    PetaniModel({
        this.id,
        this.name,
        this.noHp,
        this.password,
        this.noKtp,
        this.foto,
        this.location,
        this.surfaceAreaTotal,
        this.plantTotal,
        this.lastHarvestTotal,
        this.verified,
        this.createdAt,
        this.updatedAt,
    });

    factory PetaniModel.fromJson(Map<String, dynamic> json) => PetaniModel(
        id: json["id"],
        name: json["name"],
        noHp: json["no_hp"],
        password: json["password"],
        noKtp: json["no_ktp"],
        foto: json["foto"],
        location: json["location"],
        surfaceAreaTotal: json["surface_area_total"]?.toDouble(),
        plantTotal: json["plant_total"],
        lastHarvestTotal: json["last_harvest_total"]?.toDouble(),
        verified: json["verified"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "no_hp": noHp,
        "password": password,
        "no_ktp": noKtp,
        "foto": foto,
        "location": location,
        "surface_area_total": surfaceAreaTotal,
        "plant_total": plantTotal,
        "last_harvest_total": lastHarvestTotal,
        "verified": verified,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
