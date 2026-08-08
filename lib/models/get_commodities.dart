// To parse this JSON data, do
//
//     final getCommodities = getCommoditiesFromJson(jsonString);

import 'dart:convert';

GetCommodities getCommoditiesFromJson(String str) => GetCommodities.fromJson(json.decode(str));

String getCommoditiesToJson(GetCommodities data) => json.encode(data.toJson());

class GetCommodities {
    String? message;
    List<Datum>? data;

    GetCommodities({
        this.message,
        this.data,
    });

    factory GetCommodities.fromJson(Map<String, dynamic> json) => GetCommodities(
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
    String? commoditiesName;
    DateTime? createdAt;
    DateTime? updatedAt;

    Datum({
        this.id,
        this.commoditiesName,
        this.createdAt,
        this.updatedAt,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        commoditiesName: json["commodities_name"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "commodities_name": commoditiesName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
