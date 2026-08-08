// To parse this JSON data, do
//
//     final getPlotByKthId = getPlotByKthIdFromJson(jsonString);

import 'dart:convert';

GetPlotByKthId getPlotByKthIdFromJson(String str) => GetPlotByKthId.fromJson(json.decode(str));

String getPlotByKthIdToJson(GetPlotByKthId data) => json.encode(data.toJson());

class GetPlotByKthId {
    String? status;
    List<Datum>? data;

    GetPlotByKthId({
        this.status,
        this.data,
    });

    factory GetPlotByKthId.fromJson(Map<String, dynamic> json) => GetPlotByKthId(
        status: json["status"],
        data: json["data"] == null ? [] : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "status": status,
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    };
}

class Datum {
    int? id;
    String? plotName;
    String? landArea;
    int? numberOfPlants;
    dynamic latitude;
    dynamic longitude;
    int? farmerId;
    dynamic polygon;
    DateTime? createdAt;
    DateTime? updatedAt;
    Farmer? farmer;

    Datum({
        this.id,
        this.plotName,
        this.landArea,
        this.numberOfPlants,
        this.latitude,
        this.longitude,
        this.farmerId,
        this.polygon,
        this.createdAt,
        this.updatedAt,
        this.farmer,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        plotName: json["plot_name"],
        landArea: json["land_area"],
        numberOfPlants: json["number_of_plants"],
        latitude: json["latitude"],
        longitude: json["longitude"],
        farmerId: json["farmer_id"],
        polygon: json["polygon"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        farmer: json["farmer"] == null ? null : Farmer.fromJson(json["farmer"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "plot_name": plotName,
        "land_area": landArea,
        "number_of_plants": numberOfPlants,
        "latitude": latitude,
        "longitude": longitude,
        "farmer_id": farmerId,
        "polygon": polygon,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "farmer": farmer?.toJson(),
    };
}

class Farmer {
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
        this.password,
        this.noHp,
        this.nik,
        this.foto,
        this.preFinance,
        this.createdAt,
        this.updatedAt,
    });

    factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
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
        "foto": foto,
        "pre_finance": preFinance,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
