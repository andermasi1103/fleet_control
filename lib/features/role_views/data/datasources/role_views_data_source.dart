import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
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
  RoleViewsDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Set<AppViewCode>> getMyViews({required String sessionToken}) async {
    final response = await _invoke(
      'my-views',
      sessionToken: sessionToken,
      method: HttpMethod.get,
    );
    final values = response['views'];
    if (values is! List) {
      throw const Failure(
        message: 'La configuración de vistas no es válida.',
        type: FailureType.supabase,
      );
    }
    return AppViewCode.fromValues(values);
  }

  @override
  Future<RoleViewsMatrixDto> getMatrix({
    required String sessionToken,
  }) async {
    final response = await _invoke(
      'role-views-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
    );
    final roles = response['roles'];
    final views = response['views'];
    final assignments = response['role_views'];
    if (roles is! List || views is! List || assignments is! List) {
      throw const Failure(
        message: 'La matriz de vistas no es válida.',
        type: FailureType.supabase,
      );
    }
    try {
      return RoleViewsMatrixDto(
        roles: roles.map((item) => RoleDto.fromJson(_map(item))).toList(),
        views: views.map((item) => AppViewDto.fromJson(_map(item))).toList(),
        assignments: assignments
            .map((item) => RoleViewDto.fromJson(_map(item)))
            .toList(),
      );
    } on FormatException {
      throw const Failure(
        message: 'La matriz de vistas no es válida.',
        type: FailureType.supabase,
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
    await _invoke(
      'role-view-update',
      sessionToken: sessionToken,
      method: HttpMethod.patch,
      body: {
        'role_code': roleCode,
        'view_code': viewCode,
        'visible': visible,
      },
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    required String sessionToken,
    required HttpMethod method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        method: method,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: body,
      );
      return _map(response.data);
    } on FunctionException catch (error) {
      throw Failure(
        message: _messageFor(error.status, error.details),
        statusCode: error.status,
        type: error.status == 401
            ? FailureType.sessionExpired
            : error.status == 403
            ? FailureType.insufficientPermissions
            : FailureType.supabase,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar la configuración de vistas.',
        type: FailureType.network,
      );
    }
  }

  String _messageFor(int status, Object? details) {
    final code = details is Map ? details['error'] : null;
    if (code == 'protected_view') {
      return 'Esta vista protegida no se puede desactivar.';
    }
    return switch (status) {
      401 => 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      403 => 'No tienes permiso para administrar las vistas por rol.',
      404 => 'El rol o la vista ya no están disponibles.',
      _ => 'No fue posible guardar la configuración de vistas.',
    };
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Respuesta inválida.');
  }
}
