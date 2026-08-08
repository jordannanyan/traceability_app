// To parse this JSON data, do
//
//     final loginPetaniModel = loginPetaniModelFromJson(jsonString);

import 'dart:convert';

// Tolerant coercers: numeric columns (e.g. previous_income is DOUBLE) may arrive
// as int, double, or string; dates may be null/zero. Coerce instead of hard-cast
// so a single odd value never breaks login.
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty || s.startsWith('0000')) return null;
  return DateTime.tryParse(s);
}

LoginPetaniModel loginPetaniModelFromJson(String str) => LoginPetaniModel.fromJson(json.decode(str));

String loginPetaniModelToJson(LoginPetaniModel data) => json.encode(data.toJson());

class LoginPetaniModel {
    String? message;
    String? token;
    Farmer? farmer;

    LoginPetaniModel({
        this.message,
        this.token,
        this.farmer,
    });

    factory LoginPetaniModel.fromJson(Map<String, dynamic> json) => LoginPetaniModel(
        message: json["message"],
        token: json["token"],
        farmer: json["farmer"] == null ? null : Farmer.fromJson(json["farmer"]),
    );

    Map<String, dynamic> toJson() => {
        "message": message,
        "token": token,
        "farmer": farmer?.toJson(),
    };
}

class Farmer {
    int? id;
    String? farmerName;
    int? numberOfChildren;
    DateTime? dateOfBirth;
    int? previousIncome;
    String? address;
    int? kthId;
    dynamic noHp;
    String? nik;
    dynamic foto;
    int? preFinance;
    DateTime? createdAt;
    DateTime? updatedAt;

    Farmer({
        this.id,
        this.farmerName,
        this.numberOfChildren,
        this.dateOfBirth,
        this.previousIncome,
        this.address,
        this.kthId,
        this.noHp,
        this.nik,
        this.foto,
        this.preFinance,
        this.createdAt,
        this.updatedAt,
    });

    factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
        id: _asInt(json["id"]),
        farmerName: json["farmer_name"],
        numberOfChildren: _asInt(json["number_of_children"]),
        dateOfBirth: _asDate(json["date_of_birth"]),
        previousIncome: _asInt(json["previous_income"]),
        address: json["address"],
        kthId: _asInt(json["kth_id"]),
        noHp: json["no_hp"],
        nik: json["nik"],
        foto: json["foto"],
        preFinance: _asInt(json["pre_finance"]),
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "farmer_name": farmerName,
        "number_of_children": numberOfChildren,
        "date_of_birth": dateOfBirth == null
            ? null
            : "${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}",
        "previous_income": previousIncome,
        "address": address,
        "kth_id": kthId,
        "no_hp": noHp,
        "nik": nik,
        "foto": foto,
        "pre_finance": preFinance,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
