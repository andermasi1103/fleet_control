import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/role_option_dto.dart';
import '../dtos/user_dto.dart';
import '../dtos/user_location_option_dto.dart';

class UsersDataSource {
  UsersDataSource(this._client);

  final SupabaseClient _client;

  Future<List<UserDto>> getUsers({required String sessionToken}) async {
    final body = await _invoke(
      'users-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      fallback: 'No fue posible cargar los usuarios.',
    );
    final users = body['users'];
    if (users is! List) {
      throw const Failure(
        message: 'No fue posible cargar los usuarios.',
        type: FailureType.supabase,
      );
    }
    try {
      return users
          .map((item) => UserDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los usuarios.',
        type: FailureType.supabase,
      );
    }
  }

  Future<UserDto> createUser({
    required String sessionToken,
    required String nombre,
    required String usuario,
    required String password,
    required String? companyId,
    required String roleId,
  }) async {
    if (kDebugMode) {
      debugPrint(
        'users-create request: hasNombre=${nombre.isNotEmpty}; '
        'hasUsuario=${usuario.isNotEmpty}; hasPassword=${password.isNotEmpty}; '
        'passwordLength=${password.length}; empresaIdNull=${companyId == null}; '
        'roleIdEmpty=${roleId.isEmpty}',
      );
    }
    final body = await _invoke(
      'users-create',
      sessionToken: sessionToken,
      method: HttpMethod.post,
      payload: {
        'nombre': nombre,
        'usuario': usuario,
        'password': password,
        'empresa_id': companyId,
        'rol_id': roleId,
      },
      fallback: 'No fue posible completar la operación.',
    );
    return _userFrom(body);
  }

  Future<List<RoleOptionDto>> getRoles({required String sessionToken}) async {
    final body = await _invoke(
      'roles-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      fallback: 'No fue posible cargar los roles.',
    );
    final roles = body['roles'];
    if (roles is! List) {
      throw const Failure(
        message: 'No fue posible cargar los roles.',
        type: FailureType.supabase,
      );
    }
    try {
      return roles
          .map((item) => RoleOptionDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los roles.',
        type: FailureType.supabase,
      );
    }
  }

  Future<UserDto> updateUser({
    required String sessionToken,
    required String id,
    required String nombre,
    required String usuario,
    required String? companyId,
    required String roleId,
    required bool isActive,
  }) async {
    final body = await _invoke(
      'users-update',
      sessionToken: sessionToken,
      method: HttpMethod.patch,
      payload: {
        'id': id,
        'nombre': nombre,
        'usuario': usuario,
        'empresa_id': companyId,
        'rol_id': roleId,
        'activo': isActive,
      },
      fallback: 'No fue posible completar la operación.',
    );
    return _userFrom(body);
  }

  Future<void> resetPassword({
    required String sessionToken,
    required String userId,
    required String password,
  }) async {
    await _invoke(
      'users-reset-password',
      sessionToken: sessionToken,
      method: HttpMethod.post,
      payload: {'user_id': userId, 'new_password': password},
      fallback: 'No fue posible completar la operación.',
    );
  }

  Future<List<UserLocationOptionDto>> getUserLocations({
    required String sessionToken,
    required String userId,
  }) async {
    final body = await _invoke(
      'user-locations-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      queryParameters: {'user_id': userId},
      fallback: 'No fue posible cargar los locales del usuario.',
      isUserLocationsRequest: true,
    );
    final locations = body['locations'];
    if (locations is! List) {
      throw const Failure(
        message: 'No fue posible cargar los locales del usuario.',
        type: FailureType.supabase,
      );
    }
    try {
      final parsedLocations = locations
          .map((item) => UserLocationOptionDto.fromJson(_map(item)))
          .toList(growable: false);
      if (kDebugMode) {
        debugPrint('user-locations-list locations=${parsedLocations.length}');
      }
      return parsedLocations;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los locales del usuario.',
        type: FailureType.supabase,
      );
    }
  }

  Future<void> updateUserLocations({
    required String sessionToken,
    required String userId,
    required List<String> locationIds,
  }) async {
    if (kDebugMode) {
      debugPrint('user-locations-update selected=${locationIds.length}');
    }
    await _invoke(
      'user-locations-update',
      sessionToken: sessionToken,
      method: HttpMethod.put,
      payload: {'user_id': userId, 'location_ids': locationIds},
      fallback: 'No fue posible completar la operación.',
      isUserLocationsRequest: true,
    );
  }

  UserDto _userFrom(Map<String, dynamic> body) {
    try {
      return UserDto.fromJson(_map(body['user']));
    } on FormatException {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    required String sessionToken,
    required HttpMethod method,
    required String fallback,
    Map<String, dynamic>? payload,
    Map<String, String>? queryParameters,
    bool isUserLocationsRequest = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        method: method,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: payload,
        queryParameters: queryParameters,
      );
      if (kDebugMode && isUserLocationsRequest) {
        debugPrint('$functionName status=${response.status}');
      }
      return _map(response.data);
    } on FunctionException catch (error) {
      _debugFunctionError(functionName, error);
      throw _failureFor(
        error.status,
        fallback,
        details: error.details,
        isUserLocationsRequest: isUserLocationsRequest,
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw Failure(message: fallback, type: FailureType.supabase);
    } catch (_) {
      throw Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Failure _failureFor(
    int status,
    String fallback, {
    Object? details,
    bool isUserLocationsRequest = false,
  }) {
    final code = details is Map ? details['error']?.toString() : null;
    switch (status) {
      case 400:
        if (code == 'invalid_reference') {
          return const Failure(
            message: 'Uno de los locales seleccionados no es válido.',
            type: FailureType.supabase,
          );
        }
        return const Failure(
          message: 'Revisa los datos ingresados.',
          type: FailureType.supabase,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      case 403:
        if (isUserLocationsRequest || code == 'forbidden') {
          return const Failure(
            message:
                'No tienes permiso para administrar los locales de este usuario.',
            type: FailureType.insufficientPermissions,
          );
        }
        return const Failure(
          message: 'No tienes permiso para administrar usuarios.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El usuario ya no está disponible.',
          type: FailureType.supabase,
        );
      case 409:
        return const Failure(
          message: 'El nombre de usuario ya está en uso.',
          type: FailureType.supabase,
        );
      default:
        return Failure(message: fallback, type: FailureType.supabase);
    }
  }

  void _debugFunctionError(String functionName, FunctionException error) {
    if (!kDebugMode) return;
    final details = error.details;
    final code = details is Map ? details['error']?.toString() : null;
    final response = details is Map
        ? 'map keys: ${details.keys.map((key) => key.toString()).join(', ')}'
        : details == null
        ? 'empty'
        : details.runtimeType.toString();
    debugPrint(
      '$functionName failed: HTTP ${error.status}; code=${code ?? '-'}; response=$response',
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Respuesta inválida.');
  }
}
