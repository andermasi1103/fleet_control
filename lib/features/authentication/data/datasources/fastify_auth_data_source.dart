import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/errors/failure.dart';
import '../dtos/login_response_dto.dart';

class FastifyAuthDataSource {
  FastifyAuthDataSource(this._client);

  final ApiClient _client;

  Future<LoginResponseDto> signInWithUsuarioAndPassword({
    required String usuario,
    required String password,
  }) async {
    final normalizedUsuario = usuario.trim();

    if (normalizedUsuario.isEmpty || password.isEmpty) {
      throw const Failure(
        message: 'Usuario y contraseña son obligatorios.',
        type: FailureType.invalidCredentials,
      );
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'usuario': normalizedUsuario, 'password': password},
      );

      final body = _mapResponse(response.data);
      final loginResponse = LoginResponseDto.fromJson(body);

      if (!loginResponse.user.isActive) {
        throw const Failure(
          message: 'Tu usuario se encuentra inactivo.',
          type: FailureType.userInactive,
        );
      }

      return loginResponse;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const Failure(
          message: 'Usuario o contraseña inválidos.',
          type: FailureType.invalidCredentials,
        );
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown) {
        throw const Failure(
          message: 'No se pudo conectar con el servidor.',
          type: FailureType.network,
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const Failure(
          message: 'El servidor está tardando demasiado en responder.',
          type: FailureType.network,
        );
      }

      throw Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        statusCode: error.statusCode,
        type: FailureType.network,
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'La respuesta de inicio de sesión no es válida.',
        type: FailureType.network,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        type: FailureType.network,
      );
    }
  }

  /// Revoca la sesión custom actual en el backend.
  ///
  /// Un 401 es válido cuando la sesión ya expiró o fue revocada. El llamador
  /// siempre debe limpiar su estado local, incluso si esta operación falla.
  Future<void> signOut({required String sessionToken}) async {
    if (sessionToken.trim().isEmpty) {
      return;
    }

    try {
      await _client.post<Map<String, dynamic>>(
        '/api/auth/logout',
        bearerToken: sessionToken,
        data: const <String, dynamic>{},
      );
    } on ApiException catch (error) {
      // La sesión ya no sirve de todos modos; no impide cerrar localmente.
      if (error.statusCode == 401) {
        return;
      }

      rethrow;
    }
  }

  /// Comprueba una sesión persistida mediante un endpoint ya protegido.
  /// No renueva ni modifica el token: solo confirma que el backend lo acepta.
  Future<void> validateSession({required String sessionToken}) async {
    if (sessionToken.trim().isEmpty) {
      throw const Failure(
        message: 'La sesión almacenada no es válida.',
        type: FailureType.sessionExpired,
      );
    }

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/me/views',
        bearerToken: sessionToken,
      );
      _mapResponse(response.data);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        throw const Failure(
          message: 'Tu sesión venció. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const Failure(
          message: 'No se pudo validar la sesión con el servidor.',
          type: FailureType.network,
        );
      }
      throw Failure(
        message: 'No se pudo validar la sesión con el servidor.',
        statusCode: error.statusCode,
        type: FailureType.network,
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'La respuesta de validación de sesión no es válida.',
        type: FailureType.network,
      );
    }
  }

  Map<String, dynamic> _mapResponse(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const Failure(
      message: 'Respuesta de autenticación inválida.',
      type: FailureType.network,
    );
  }
}
