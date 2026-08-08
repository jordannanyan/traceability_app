import 'dart:convert';

GetPlotByFarmerId getPlotByFarmerIdFromJson(String str) =>
    GetPlotByFarmerId.fromJson(json.decode(str));

String getPlotByFarmerIdToJson(GetPlotByFarmerId data) =>
    json.encode(data.toJson());

class GetPlotByFarmerId {
  String? status;
  List<Datum> data;

  GetPlotByFarmerId({
    this.status,
    List<Datum>? data,
  }) : data = data ?? <Datum>[];

  factory GetPlotByFarmerId.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final list = (raw is List) ? raw : <dynamic>[];
    return GetPlotByFarmerId(
      status: json['status']?.toString(),
      data: list.map((x) => Datum.fromJson(Map<String, dynamic>.from(x))).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'data': data.map((x) => x.toJson()).toList(),
      };
}

class Datum {
  int? id;
  String? plotName;
  String? landArea;
  int? numberOfPlants;
  String? latitude;
  String? longitude;
  int? farmerId;

  /// WKT string: "POLYGON((lng lat, lng lat, ...))"
  String? polygonWkt;

  DateTime? createdAt;
  DateTime? updatedAt;

  Datum({
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

  static String? _toStringOrJson(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    try {
      return jsonEncode(v);
    } catch (_) {
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
  }

  factory Datum.fromJson(Map<String, dynamic> json) {
    // ✅ Prioritas: polygon_wkt (output dari backend yang aman)
    String? poly = _toStringOrJson(json['polygon_wkt']);

    // fallback lama: polygon
    poly ??= _toStringOrJson(json['polygon']);

    return Datum(
      id: _toInt(json['id']),
      plotName: json['plot_name']?.toString(),
      landArea: json['land_area']?.toString(),
      numberOfPlants: _toInt(json['number_of_plants']),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      farmerId: _toInt(json['farmer_id']),
      polygonWkt: poly,
      createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null ? null : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plot_name': plotName,
        'land_area': landArea,
        'number_of_plants': numberOfPlants,
        'latitude': latitude,
        'longitude': longitude,
        'farmer_id': farmerId,

        // untuk request ke backend, pakai field 'polygon'
        'polygon': polygonWkt,

        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
