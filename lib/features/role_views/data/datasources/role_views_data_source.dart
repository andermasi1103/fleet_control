import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../app_view_code.dart';
import '../dtos/role_views_dto.dart';

abstract class RoleViewsGateway {
  Future<Set<AppViewCode>> getMyViews({required String sessionToken});
  Future<RoleViewsMatrixDto> getMatrix({required String sessionToken});
  Future<void> updateView({
    required String sessionToken,
    required String roleCode,
    required String viewCode,
    required bool visible,
  });
}

class RoleViewsDataSource implements RoleViewsGateway {
  RoleViewsDataSource(this._apiClient);
  final ApiClient _apiClient;
  @override
  Future<Set<AppViewCode>> getMyViews({required String sessionToken}) async {
    try {
      final values = (await _apiClient.get<Map<String, dynamic>>(
        '/api/me/views',
        bearerToken: sessionToken,
      )).data?['views'];
      if (values is! List) {
        throw const FormatException();
      }
      return AppViewCode.fromValues(values);
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible cargar las vistas disponibles.',
      );
    } on FormatException {
      throw const Failure(
        message: 'La configuración de vistas no es válida.',
        type: FailureType.network,
      );
    }
  }

  @override
  Future<RoleViewsMatrixDto> getMatrix({required String sessionToken}) async {
    try {
      final body =
          (await _apiClient.get<Map<String, dynamic>>(
            '/api/role-views',
            bearerToken: sessionToken,
          )).data ??
          {};
      final roles = body['roles'];
      final views = body['views'];
      final assignments = body['role_views'];
      if (roles is! List || views is! List || assignments is! List) {
        throw const FormatException();
      }
      return RoleViewsMatrixDto(
        roles: roles.map((item) => RoleDto.fromJson(_map(item))).toList(),
        views: views.map((item) => AppViewDto.fromJson(_map(item))).toList(),
        assignments: assignments
            .map((item) => RoleViewDto.fromJson(_map(item)))
            .toList(),
      );
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible cargar la configuración de vistas.',
      );
    } on FormatException {
      throw const Failure(
        message: 'La matriz de vistas no es válida.',
        type: FailureType.network,
      );
    }
  }

  @override
  Future<void> updateView({
    required String sessionToken,
    required String roleCode,
    required String viewCode,
    required bool visible,
  }) async {
    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/api/role-views',
        bearerToken: sessionToken,
        data: {
          'role_code': roleCode,
          'view_code': viewCode,
          'visible': visible,
        },
      );
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible guardar la configuración de vistas.',
        code: error.code,
      );
    }
  }

  Failure _failure(int? status, String fallback, {String? code}) {
    if (code == 'protected_view' || status == 400) {
      return const Failure(
        message: 'Esta vista protegida no se puede desactivar.',
        type: FailureType.network,
      );
    }
    return switch (status) {
      401 => const Failure(
        message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
        type: FailureType.sessionExpired,
      ),
      403 => const Failure(
        message: 'No tienes permiso para administrar las vistas por rol.',
        type: FailureType.insufficientPermissions,
      ),
      404 => const Failure(
        message: 'El rol o la vista ya no están disponibles.',
        type: FailureType.network,
      ),
      _ => Failure(message: fallback, type: FailureType.network),
    };
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException();
  }
}
