import 'package:dio/dio.dart';
import 'package:traceability_app/models/login_petani_model.dart';
import 'package:traceability_app/utils/utils.dart';

class LoginPetaniApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<LoginPetaniModel> login(String noHp, String password) async {
    try {

      final response = await _dio.post(
        '/login/farmer',
        data: {'nik': noHp, 'password': password},
      );


      // Check for success response
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is! Map<String, dynamic>) {
          throw Exception('Unexpected response shape');
        }
        return LoginPetaniModel.fromJson(data);
      } else {
        throw Exception(_extractMessage(response.data, 'Unknown error occurred'));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(_extractMessage(e.response?.data, 'Server error occurred'));
      } else {
        throw Exception('Connection error: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  String _extractMessage(dynamic data, String fallback) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    if (data is String && data.isNotEmpty) return data;
    return fallback;
  }
}
