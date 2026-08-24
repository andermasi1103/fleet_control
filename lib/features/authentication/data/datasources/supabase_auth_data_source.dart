import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/login_response_dto.dart';

class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client);

  final SupabaseClient _client;

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
      final response = await _client.functions.invoke(
        'auth-login',
        body: {
          'usuario': normalizedUsuario,
          'password': password,
        },
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
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw const Failure(
          message: 'Usuario o contraseña inválidos.',
          type: FailureType.invalidCredentials,
        );
      }

      throw const Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        type: FailureType.supabase,
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'La respuesta de inicio de sesión no es válida.',
        type: FailureType.supabase,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        type: FailureType.supabase,
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
      final response = await _client.functions.invoke(
        'session-logout',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer $sessionToken'},
      );

      if (kDebugMode) {
        debugPrint('session-logout status=${response.status}');
      }
    } on FunctionException catch (error) {
      if (kDebugMode) {
        debugPrint('session-logout status=${error.status}');
      }

      // La sesión ya no sirve de todos modos; no impide cerrar localmente.
      if (error.status == 401) {
        return;
      }

      rethrow;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('session-logout request failed');
      }
      rethrow;
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
      type: FailureType.supabase,
    );
  }
}
