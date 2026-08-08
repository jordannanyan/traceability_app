// To parse this JSON data, do
//
//     final addPlot = addPlotFromJson(jsonString);

import 'dart:convert';

AddPlot addPlotFromJson(String str) => AddPlot.fromJson(json.decode(str));

String addPlotToJson(AddPlot data) => json.encode(data.toJson());

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '.');
  return double.tryParse(s);
}

class AddPlot {
  String? message;
  Data? data;

  AddPlot({this.message, this.data});

  factory AddPlot.fromJson(Map<String, dynamic> json) => AddPlot(
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {"message": message, "data": data?.toJson()};
}

class Data {
  String? plotName;
  dynamic landArea;
  int? numberOfPlants;
  double? latitude;
  double? longitude;
  int? farmerId;
  DateTime? updatedAt;
  DateTime? createdAt;
  int? id;

  Data({
    this.plotName,
    this.landArea,
    this.numberOfPlants,
    this.latitude,
    this.longitude,
    this.farmerId,
    this.updatedAt,
    this.createdAt,
    this.id,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    plotName: json["plot_name"],
    landArea: json["land_area"],
    numberOfPlants: json["number_of_plants"],
    latitude: _asDouble(json["latitude"]),
    longitude: _asDouble(json["longitude"]),

    farmerId: json["farmer_id"],
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    id: json["id"],
  );

  Map<String, dynamic> toJson() => {
    "plot_name": plotName,
    "land_area": landArea,
    "number_of_plants": numberOfPlants,
    "latitude": latitude,
    "longitude": longitude,
    "farmer_id": farmerId,
    "updated_at": updatedAt?.toIso8601String(),
    "created_at": createdAt?.toIso8601String(),
    "id": id,
  };
}
