// To parse this JSON data, do
//
//     final updateFarmer = updateFarmerFromJson(jsonString);

import 'dart:convert';

UpdateFarmer updateFarmerFromJson(String str) => UpdateFarmer.fromJson(json.decode(str));

String updateFarmerToJson(UpdateFarmer data) => json.encode(data.toJson());

class UpdateFarmer {
    String? message;
    Data? data;

    UpdateFarmer({
        this.message,
        this.data,
    });

    factory UpdateFarmer.fromJson(Map<String, dynamic> json) => UpdateFarmer(
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
    String? farmerName;
    int? numberOfChildren;
    dynamic dateOfBirth;
    int? previousIncome;
    String? address;
    int? kthId;
    String? password;
    dynamic noHp;
    String? nik;
    String? noRek;
    dynamic foto;
    int? preFinance;
    DateTime? createdAt;
    DateTime? updatedAt;

    Data({
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
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
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
    };
}
