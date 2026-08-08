// To parse this JSON data, do
//
//     final getDistributedSaprodiByPlotId = getDistributedSaprodiByPlotIdFromJson(jsonString);

import 'dart:convert';

// Tolerant coercers: numeric/decimal columns can arrive as int, double, or
// string (e.g. quantity/price as "66"/"2300.00"); a hard cast throws
// "String is not a subtype of int" and blanks the whole screen. Coerce instead.
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

String? _asStr(dynamic v) => v?.toString();

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty || s.startsWith('0000')) return null;
  return DateTime.tryParse(s);
}

GetDistributedSaprodiByPlotId getDistributedSaprodiByPlotIdFromJson(String str) => GetDistributedSaprodiByPlotId.fromJson(json.decode(str));

String getDistributedSaprodiByPlotIdToJson(GetDistributedSaprodiByPlotId data) => json.encode(data.toJson());

class GetDistributedSaprodiByPlotId {
    String? status;
    List<Datum>? data;

    GetDistributedSaprodiByPlotId({
        this.status,
        this.data,
    });

    factory GetDistributedSaprodiByPlotId.fromJson(Map<String, dynamic> json) => GetDistributedSaprodiByPlotId(
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
    DateTime? date;
    int? plotId;
    int? commoditiesId;
    int? sapropdiId;
    int? quantity;
    String? pricePerUnit;
    String? totalPrice;
    dynamic uploadProof;
    DateTime? createdAt;
    DateTime? updatedAt;
    Sapropdi? sapropdi;
    Plot? plot;
    Commodities? commodities;

    Datum({
        this.id,
        this.date,
        this.plotId,
        this.commoditiesId,
        this.sapropdiId,
        this.quantity,
        this.pricePerUnit,
        this.totalPrice,
        this.uploadProof,
        this.createdAt,
        this.updatedAt,
        this.sapropdi,
        this.plot,
        this.commodities,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: _asInt(json["id"]),
        date: _asDate(json["date"]),
        plotId: _asInt(json["plot_id"]),
        commoditiesId: _asInt(json["commodities_id"]),
        sapropdiId: _asInt(json["sapropdi_id"]),
        quantity: _asInt(json["quantity"]),
        pricePerUnit: _asStr(json["price_per_unit"]),
        totalPrice: _asStr(json["total_price"]),
        uploadProof: json["upload_proof"],
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
        sapropdi: json["sapropdi"] == null ? null : Sapropdi.fromJson(json["sapropdi"]),
        plot: json["plot"] == null ? null : Plot.fromJson(json["plot"]),
        commodities: json["commodities"] == null ? null : Commodities.fromJson(json["commodities"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "date": date == null
            ? null
            : "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
        "plot_id": plotId,
        "commodities_id": commoditiesId,
        "sapropdi_id": sapropdiId,
        "quantity": quantity,
        "price_per_unit": pricePerUnit,
        "total_price": totalPrice,
        "upload_proof": uploadProof,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "sapropdi": sapropdi?.toJson(),
        "plot": plot?.toJson(),
        "commodities": commodities?.toJson(),
    };
}

class Commodities {
    int? id;
    String? commoditiesName;
    DateTime? createdAt;
    DateTime? updatedAt;

    Commodities({
        this.id,
        this.commoditiesName,
        this.createdAt,
        this.updatedAt,
    });

    factory Commodities.fromJson(Map<String, dynamic> json) => Commodities(
        id: _asInt(json["id"]),
        commoditiesName: json["commodities_name"],
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "commodities_name": commoditiesName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}

class Plot {
    int? id;
    String? plotName;
    String? landArea;
    int? numberOfPlants;
    String? latitude;
    String? longitude;
    int? farmerId;
    dynamic polygon;
    DateTime? createdAt;
    DateTime? updatedAt;

    Plot({
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
    });

    factory Plot.fromJson(Map<String, dynamic> json) => Plot(
        id: _asInt(json["id"]),
        plotName: json["plot_name"],
        landArea: _asStr(json["land_area"]),
        numberOfPlants: _asInt(json["number_of_plants"]),
        latitude: _asStr(json["latitude"]),
        longitude: _asStr(json["longitude"]),
        farmerId: _asInt(json["farmer_id"]),
        polygon: json["polygon"],
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
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
    };
}

class Sapropdi {
    int? id;
    String? sapropdiName;
    String? unit;
    DateTime? createdAt;
    DateTime? updatedAt;

    Sapropdi({
        this.id,
        this.sapropdiName,
        this.unit,
        this.createdAt,
        this.updatedAt,
    });

    factory Sapropdi.fromJson(Map<String, dynamic> json) => Sapropdi(
        id: _asInt(json["id"]),
        sapropdiName: json["sapropdi_name"],
        unit: _asStr(json["unit"]),
        createdAt: _asDate(json["created_at"]),
        updatedAt: _asDate(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "sapropdi_name": sapropdiName,
        "unit": unit,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
