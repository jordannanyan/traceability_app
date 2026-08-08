// To parse this JSON data, do
//
//     final loginModel = loginModelFromJson(jsonString);

import 'dart:convert';

LoginModel loginModelFromJson(String str) => LoginModel.fromJson(json.decode(str));

String loginModelToJson(LoginModel data) => json.encode(data.toJson());

class LoginModel {
    String? message;
    String? token;
    Kth? kth;

    LoginModel({
        this.message,
        this.token,
        this.kth,
    });

    factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
        message: json["message"],
        token: json["token"],
        kth: json["kth"] == null ? null : Kth.fromJson(json["kth"]),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "token": token,
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
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
