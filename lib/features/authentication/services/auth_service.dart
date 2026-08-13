import 'dart:developer' as developer;
import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../users/models/user_model.dart';
import '../models/login_result.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "${AppConstants.apiUrl}/rest/v1/",
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        "apikey": AppConstants.apiKey,
        "Authorization": "Bearer ${AppConstants.apiKey}",
      },
    ),
  );

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      developer.log("➡️ Consultando Supabase REST FleetControl", name: "AuthService");

      final response = await _dio.get(
        "FleetControl",
        queryParameters: {
          "select": "*",
          "usuario": "eq.$username",
          "password": "eq.$password",
        },
      );

      developer.log("⬅️ Status code: ${response.statusCode}", name: "AuthService");
      developer.log("⬅️ Raw response: ${response.data}", name: "AuthService");

      final data = response.data as List;

      if (data.isNotEmpty) {
        final user = UserModel.fromJson(Map<String, dynamic>.from(data.first));

        // 🔹 Bloquear usuarios inactivos
        if (!user.isActive) {
          developer.log("❌ Usuario inactivo: ${user.usuario}", name: "AuthService");
          return LoginResult(
            isSuccess: false,
            message: "Usuario inactivo",
          );
        }

        developer.log(
          "✅ Login exitoso: usuario=${user.usuario}, rol=${user.rol}, activo=${user.isActive}",
          name: "AuthService",
        );

        return LoginResult(
          isSuccess: true,
          user: user,
          message: "Login exitoso",
        );
      }

      developer.log("❌ Login fallido: usuario o contraseña inválidos", name: "AuthService");
      return LoginResult(isSuccess: false, message: "Credenciales inválidas");
    } on DioException catch (e) {
      developer.log("⚠️ DioException: ${e.message}", name: "AuthService");
      return LoginResult(isSuccess: false, message: "Error de conexión: ${e.message}");
    } catch (e) {
      developer.log("⚠️ Error inesperado: $e", name: "AuthService");
      return LoginResult(isSuccess: false, message: "Error inesperado: $e");
    }
  }
}
