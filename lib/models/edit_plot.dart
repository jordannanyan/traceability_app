// lib/models/edit_plot.dart
// DROP-IN REPLACEMENT (robust parsing for latitude/longitude that may be String or num)

import 'dart:convert';

EditPlot editPlotFromJson(String str) => EditPlot.fromJson(json.decode(str));
String editPlotToJson(EditPlot data) => json.encode(data.toJson());

class EditPlot {
  String? message;
  Data? data;

  EditPlot({this.message, this.data});

  factory EditPlot.fromJson(Map<String, dynamic> json) => EditPlot(
        message: json["message"]?.toString(),
        data: json["data"] == null ? null : Data.fromJson(Map<String, dynamic>.from(json["data"])),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
      };
}

class Data {
  int? id;
  String? plotName;
  dynamic landArea;
  int? numberOfPlants;
  double? latitude;
  double? longitude;
  int? farmerId;

  /// Backend kamu kadang kirim polygon_wkt, kadang polygon
  String? polygonWkt;

  DateTime? createdAt;
  DateTime? updatedAt;

  Data({
    this.id,
    this.plotName,
    this.landArea,
    this.numberOfPlants,
    this.latitude,
    this.longitude,
    this.farmerId,
    this.polygonWkt,
    this.createdAt,
    this.updatedAt,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        id: _toInt(json["id"]),
        plotName: json["plot_name"]?.toString(),
        landArea: json["land_area"],
        numberOfPlants: _toInt(json["number_of_plants"]),
        latitude: _toDouble(json["latitude"]),
        longitude: _toDouble(json["longitude"]),
        farmerId: _toInt(json["farmer_id"]),
        polygonWkt: (json["polygon_wkt"] ?? json["polygon"])?.toString(),
        createdAt: json["created_at"] == null ? null : DateTime.tryParse(json["created_at"].toString()),
        updatedAt: json["updated_at"] == null ? null : DateTime.tryParse(json["updated_at"].toString()),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "plot_name": plotName,
        "land_area": landArea,
        "number_of_plants": numberOfPlants,
        "latitude": latitude,
        "longitude": longitude,
        "farmer_id": farmerId,
        "polygon_wkt": polygonWkt,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
