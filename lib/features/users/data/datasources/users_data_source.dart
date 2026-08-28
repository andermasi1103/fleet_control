import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/role_option_dto.dart';
import '../dtos/user_dto.dart';
import '../dtos/user_location_option_dto.dart';

class UsersDataSource {
  UsersDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<List<UserDto>> getUsers({required String sessionToken}) => _list(
    '/api/users',
    sessionToken,
    'users',
    UserDto.fromJson,
    'No fue posible cargar los usuarios.',
  );
  Future<List<RoleOptionDto>> getRoles({required String sessionToken}) => _list(
    '/api/roles',
    sessionToken,
    'roles',
    RoleOptionDto.fromJson,
    'No fue posible cargar los roles.',
  );
  Future<List<UserLocationOptionDto>> getUserLocations({
    required String sessionToken,
    required String userId,
  }) => _list(
    '/api/users/$userId/locations',
    sessionToken,
    'locations',
    UserLocationOptionDto.fromJson,
    'No fue posible cargar los locales del usuario.',
    userLocations: true,
  );

  Future<UserDto> createUser({
    required String sessionToken,
    required String nombre,
    required String usuario,
    required String password,
    required String? companyId,
    required String roleId,
  }) => _save('/api/users', sessionToken, {
    'nombre': nombre,
    'usuario': usuario,
    'password': password,
    'empresa_id': companyId,
    'rol_id': roleId,
  });
  Future<UserDto> updateUser({
    required String sessionToken,
    required String id,
    required String nombre,
    required String usuario,
    required String? companyId,
    required String roleId,
    required bool isActive,
  }) => _save('/api/users/$id', sessionToken, {
    'nombre': nombre,
    'usuario': usuario,
    'empresa_id': companyId,
    'rol_id': roleId,
    'activo': isActive,
  }, patch: true);
  Future<void> resetPassword({
    required String sessionToken,
    required String userId,
    required String password,
  }) async => _send('/api/users/$userId/password-reset', sessionToken, {
    'password': password,
  });
  Future<void> updateUserLocations({
    required String sessionToken,
    required String userId,
    required List<String> locationIds,
  }) async => _send(
    '/api/users/$userId/locations',
    sessionToken,
    {'location_ids': locationIds},
    put: true,
    userLocations: true,
  );

  Future<UserDto> _save(
    String path,
    String token,
    Map<String, dynamic> data, {
    bool patch = false,
  }) async {
    try {
      final response = patch
          ? await _apiClient.patch<Map<String, dynamic>>(
              path,
              data: data,
              bearerToken: token,
            )
          : await _apiClient.post<Map<String, dynamic>>(
              path,
              data: data,
              bearerToken: token,
            );
      return UserDto.fromJson(_map(response.data?['user']));
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible completar la operación.',
      );
    } on FormatException {
      return _invalid('No fue posible completar la operación.');
    }
  }

  Future<void> _send(
    String path,
    String token,
    Map<String, dynamic> data, {
    bool put = false,
    bool userLocations = false,
  }) async {
    try {
      if (put) {
        await _apiClient.put<Map<String, dynamic>>(
          path,
          data: data,
          bearerToken: token,
        );
      } else {
        await _apiClient.post<Map<String, dynamic>>(
          path,
          data: data,
          bearerToken: token,
        );
      }
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible completar la operación.',
        userLocations: userLocations,
      );
    }
  }

  Future<List<T>> _list<T>(
    String path,
    String token,
    String key,
    T Function(Map<String, dynamic>) parse,
    String fallback, {
    bool userLocations = false,
  }) async {
    try {
      final values = (await _apiClient.get<Map<String, dynamic>>(
        path,
        bearerToken: token,
      )).data?[key];
      if (values is! List) return _invalid(fallback);
      return values.map((item) => parse(_map(item))).toList(growable: false);
    } on ApiException catch (error) {
      throw _failure(error.statusCode, fallback, userLocations: userLocations);
    } on FormatException {
      return _invalid(fallback);
    }
  }

  Never _invalid(String message) =>
      throw Failure(message: message, type: FailureType.network);
  Failure _failure(
    int? status,
    String fallback, {
    bool userLocations = false,
  }) => switch (status) {
    400 => Failure(
      message: userLocations
          ? 'Uno de los locales seleccionados no es válido.'
          : 'Revisa los datos ingresados.',
      type: FailureType.network,
    ),
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => Failure(
      message: userLocations
          ? 'No tienes permiso para administrar los locales de este usuario.'
          : 'No tienes permiso para administrar usuarios.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'El usuario ya no está disponible.',
      type: FailureType.network,
    ),
    409 => const Failure(
      message: 'El nombre de usuario ya está en uso.',
      type: FailureType.network,
    ),
    _ => Failure(message: fallback, type: FailureType.network),
  };
  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}
