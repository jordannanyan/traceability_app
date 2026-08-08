// To parse this JSON data, do
//
//     final getFarmerById = getFarmerByIdFromJson(jsonString);

import 'dart:convert';

// Tolerant coercers: the API's numeric columns (e.g. previous_income is DOUBLE)
// can arrive as int, double, or string. A hard cast throws and silently blanks
// the screen, so coerce instead.
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

GetFarmerById getFarmerByIdFromJson(String str) => GetFarmerById.fromJson(json.decode(str));

String getFarmerByIdToJson(GetFarmerById data) => json.encode(data.toJson());

class GetFarmerById {
    String? message;
    Data? data;

    GetFarmerById({
        this.message,
        this.data,
    });

    factory GetFarmerById.fromJson(Map<String, dynamic> json) => GetFarmerById(
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
    DateTime? dateOfBirth;
    int? previousIncome;
    String? address;
    int? kthId;
    String? password;
    String? noHp;
    String? nik;
    String? noRek;
    String? foto;
    int? preFinance;
    DateTime? createdAt;
    DateTime? updatedAt;
    Kth? kth;

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
        this.kth,
    });

    factory Data.fromJson(Map<String, dynamic> json) => Data(
        id: _asInt(json["id"]),
        farmerName: json["farmer_name"],
        numberOfChildren: _asInt(json["number_of_children"]),
        dateOfBirth: _asDate(json["date_of_birth"]),
        previousIncome: _asInt(json["previous_income"]),
        address: json["address"],
        kthId: _asInt(json["kth_id"]),
        password: json["password"],
        noHp: json["no_hp"],
        nik: json["nik"],
        noRek: json["no_rek"],
        foto: json["foto"],
        preFinance: _asInt(json["pre_finance"]),
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
        kth: json["kth"] == null ? null : Kth.fromJson(json["kth"]),
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
        id: _asInt(json["id"]),
        kthName: json["kth_name"],
        address: json["address"],
        regency: json["regency"],
        partnershipPeriod: json["partnership_period"]?.toString(),
        entitiesId: _asInt(json["entities_id"]),
        username: json["username"],
        password: json["password"],
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
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
