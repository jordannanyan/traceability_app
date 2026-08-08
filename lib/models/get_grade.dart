// To parse this JSON data, do
//
//     final getGrade = getGradeFromJson(jsonString);

import 'dart:convert';

List<GetGrade> getGradeFromJson(String str) {
  // agro-api returns { data: [...] }; the old API returned a bare array.
  final decoded = json.decode(str);
  final list = decoded is List
      ? decoded
      : (decoded is Map && decoded['data'] is List ? decoded['data'] as List : const <dynamic>[]);
  return List<GetGrade>.from(list.map((x) => GetGrade.fromJson(x)));
}

String getGradeToJson(List<GetGrade> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class GetGrade {
    int? id;
    String? gradeName;
    DateTime? createdAt;
    DateTime? updatedAt;

    GetGrade({
        this.id,
        this.gradeName,
        this.createdAt,
        this.updatedAt,
    });

    factory GetGrade.fromJson(Map<String, dynamic> json) => GetGrade(
        id: json["id"],
        gradeName: json["grade_name"],
        createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "id": id,
        "grade_name": gradeName,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
    };
}
