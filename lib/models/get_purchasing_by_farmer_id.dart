// To parse this JSON data, do
//
//     final getPurchasingByFarmerId = getPurchasingByFarmerIdFromJson(jsonString);

import 'dart:convert';

GetPurchasingByFarmerId getPurchasingByFarmerIdFromJson(String str) => GetPurchasingByFarmerId.fromJson(json.decode(str));

String getPurchasingByFarmerIdToJson(GetPurchasingByFarmerId data) => json.encode(data.toJson());

class GetPurchasingByFarmerId {
    String? status;
    List<Datum>? data;

    GetPurchasingByFarmerId({
        this.status,
        this.data,
    });

    factory GetPurchasingByFarmerId.fromJson(Map<String, dynamic> json) => GetPurchasingByFarmerId(
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
    int? warehouseId;
    int? commoditiesId;
    String? quantity;
    int? gradeId;
    int? pricePerKg;
    int? valuePurchased;
    dynamic uploadProofValue;
    int? deduction;
    dynamic uploadProofDeduction;
    int? netPayment;
    dynamic uploadProofPayment;
    String? status;
    DateTime? createdAt;
    DateTime? updatedAt;
    Plot? plot;
    Warehouse? warehouse;
    Commodity? commodity;
    Commodity? grade;

    Datum({
        this.id,
        this.date,
        this.plotId,
        this.warehouseId,
        this.commoditiesId,
        this.quantity,
        this.gradeId,
        this.pricePerKg,
        this.valuePurchased,
        this.uploadProofValue,
        this.deduction,
        this.uploadProofDeduction,
        this.netPayment,
        this.uploadProofPayment,
        this.status,
        this.createdAt,
        this.updatedAt,
        this.plot,
        this.warehouse,
        this.commodity,
        this.grade,
    });

    factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        date: json["date"] == null ? null : DateTime.parse(json["date"]),
        plotId: json["plot_id"],
        warehouseId: json["warehouse_id"],
        commoditiesId: json["commodities_id"],
        quantity: json["quantity"],
        gradeId: json["grade_id"],
        pricePerKg: json["price_per_kg"],
        valuePurchased: json["value_purchased"],
        uploadProofValue: json["upload_proof_value"],
        deduction: json["deduction"],
        uploadProofDeduction: json["upload_proof_deduction"],
        netPayment: json["net_payment"],
        uploadProofPayment: json["upload_proof_payment"],
        status: json["STATUS"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        plot: json["plot"] == null ? null : Plot.fromJson(json["plot"]),
        warehouse: json["warehouse"] == null ? null : Warehouse.fromJson(json["warehouse"]),
        commodity: json["commodity"] == null ? null : Commodity.fromJson(json["commodity"]),
        grade: json["grade"] == null ? null : Commodity.fromJson(json["grade"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "date": "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}",
        "plot_id": plotId,
        "warehouse_id": warehouseId,
        "commodities_id": commoditiesId,
        "quantity": quantity,
        "grade_id": gradeId,
        "price_per_kg": pricePerKg,
        "value_purchased": valuePurchased,
        "upload_proof_value": uploadProofValue,
        "deduction": deduction,
        "upload_proof_deduction": uploadProofDeduction,
        "net_payment": netPayment,
        "upload_proof_payment": uploadProofPayment,
        "STATUS": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "plot": plot?.toJson(),
        "warehouse": warehouse?.toJson(),
        "commodity": commodity?.toJson(),
        "grade": grade?.toJson(),
    };
}

class Commodity {
    int? id;
    String? commoditiesName;
    DateTime? createdAt;
    DateTime? updatedAt;
    String? gradeName;

    Commodity({
        this.id,
        this.commoditiesName,
        this.createdAt,
        this.updatedAt,
        this.gradeName,
    });

    factory Commodity.fromJson(Map<String, dynamic> json) => Commodity(
        id: json["id"],
        commoditiesName: json["commodities_name"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
        gradeName: json["grade_name"],
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "commodities_name": commoditiesName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "grade_name": gradeName,
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

class Warehouse {
    int? id;
    String? warehouseName;
    String? address;
    int? kthId;
    DateTime? createdAt;
    DateTime? updatedAt;

    Warehouse({
        this.id,
        this.warehouseName,
        this.address,
        this.kthId,
        this.createdAt,
        this.updatedAt,
    });

    factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: json["id"],
        warehouseName: json["warehouse_name"],
        address: json["address"],
        kthId: json["kth_id"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "warehouse_name": warehouseName,
        "address": address,
        "kth_id": kthId,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
