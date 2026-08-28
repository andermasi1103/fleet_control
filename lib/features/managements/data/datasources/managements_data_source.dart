import 'package:flutter/foundation.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/management_dto.dart';

class ManagementsDataSource {
  ManagementsDataSource(this.c);
  final ApiClient c;
  Future<Map<String, dynamic>> _call(
    String path,
    String t,
    String method, {
    Object? body,
    Map<String, String>? q,
  }) async {
    try {
      final r = switch (method) {
        'GET' => await c.get<Map<String, dynamic>>(
          path,
          bearerToken: t,
          queryParameters: q,
        ),
        'POST' => await c.post<Map<String, dynamic>>(
          path,
          bearerToken: t,
          data: body,
          queryParameters: q,
        ),
        _ => throw StateError('Método no soportado.'),
      };
      if (kDebugMode && path.endsWith('/status')) {
        debugPrint(
          'management-update response: '
          'statusCode=${r.statusCode} code=${_backendCode(r.data) ?? 'none'}',
        );
      }
      return Map<String, dynamic>.from(r.data ?? const {});
    } on ApiException catch (e) {
      final backendCode = e.code;
      if (kDebugMode && path.endsWith('/status')) {
        debugPrint(
          'management-update response: '
          'statusCode=${e.statusCode} code=${backendCode ?? 'none'}',
        );
      }
      throw Failure(
        message: switch (backendCode) {
          'active_management_exists' =>
            'Ya tienes otra gestión activa. Complétala antes de iniciar la siguiente.',
          _ => switch (e.statusCode) {
            401 => 'Tu sesión ha vencido. Inicia sesión nuevamente.',
            403 => 'No tienes permiso para realizar esta acción.',
            409 => 'No se puede realizar ese cambio de estado.',
            404 => 'La gestión ya no está disponible.',
            500 => 'No fue posible actualizar la gestión.',
            _ => 'No fue posible completar la operación.',
          },
        },
        code: backendCode ?? (e.statusCode == 404 ? 'not_found' : null),
        statusCode: e.statusCode,
        type: FailureType.backend,
      );
    }
  }

  String? _backendCode(Object? value) =>
      value is Map && value['error'] is String
      ? value['error'] as String
      : null;

  Future<List<ManagementDto>> list(String t, {String? orderId}) =>
      _call(
        '/api/managements',
        t,
        'GET',
        q: {'limit': '50', 'offset': '0', 'order_id': ?orderId},
      ).then(
        (x) => (x['managements'] as List)
            .map((e) => ManagementDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Future<ManagementDto> detail(String t, String id) =>
      _call('/api/managements/$id', t, 'GET').then(
        (x) => ManagementDto.fromJson(
          Map<String, dynamic>.from(x['management'])..['events'] = x['events'],
        ),
      );
  Future<List<DriverDto>> drivers(String t, String company) =>
      _call('/api/drivers', t, 'GET', q: {'empresa_id': company}).then(
        (x) => (x['drivers'] as List)
            .map((e) => DriverDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Future<ManagementDto> create(String t, CreateManagementRequest r) =>
      _call('/api/managements', t, 'POST', body: r.toJson()).then(
        (x) =>
            ManagementDto.fromJson(Map<String, dynamic>.from(x['management'])),
      );
  Future<ManagementDto> status(String t, String id, String s) {
    if (kDebugMode) {
      debugPrint('management-update request: managementId=$id status=$s');
    }
    return _call(
      '/api/managements/$id/status',
      t,
      'POST',
      body: {'status': s},
    ).then(
      (x) => ManagementDto.fromJson(Map<String, dynamic>.from(x['management'])),
    );
  }
}
