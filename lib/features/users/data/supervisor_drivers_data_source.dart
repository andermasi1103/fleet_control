import '../../../core/errors/failure.dart';
import '../../../core/network/api_client.dart';

class SupervisorDriverDto {
  const SupervisorDriverDto({
    required this.id,
    required this.usuario,
    required this.nombre,
  });
  final String id;
  final String usuario;
  final String nombre;
  factory SupervisorDriverDto.fromJson(Map<String, dynamic> json) =>
      SupervisorDriverDto(
        id: json['id'] as String,
        usuario: json['usuario'] as String,
        nombre: json['nombre'] as String,
      );
}

class SupervisorDriversDto {
  const SupervisorDriversDto({
    required this.drivers,
    required this.assignedIds,
  });
  final List<SupervisorDriverDto> drivers;
  final Set<String> assignedIds;
}

class SupervisorDriversDataSource {
  SupervisorDriversDataSource(this._apiClient);
  final ApiClient _apiClient;
  Future<SupervisorDriversDto> load(String token, String supervisorId) async {
    try {
      final body =
          (await _apiClient.get<Map<String, dynamic>>(
            '/api/supervisors/$supervisorId/drivers',
            bearerToken: token,
          )).data ??
          {};
      final availableDrivers = body['available_drivers'];
      final assignedDrivers = body['assigned_drivers'];
      final assigned = body['assigned_driver_ids'];
      if (availableDrivers is! List ||
          assignedDrivers is! List ||
          assigned is! List) {
        throw const FormatException();
      }
      final drivers = [
        ...availableDrivers,
        ...assignedDrivers,
      ].map((item) => SupervisorDriverDto.fromJson(_map(item))).toList();
      final driversById = {for (final driver in drivers) driver.id: driver};
      return SupervisorDriversDto(
        drivers: driversById.values.toList(growable: false),
        assignedIds: assigned.map((item) => item.toString()).toSet(),
      );
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible cargar los choferes asignados.',
      );
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los choferes asignados.',
        type: FailureType.network,
      );
    }
  }

  Future<void> save(String token, String supervisorId, Set<String> ids) async {
    try {
      await _apiClient.put<Map<String, dynamic>>(
        '/api/supervisors/$supervisorId/drivers',
        bearerToken: token,
        data: {'driver_user_ids': ids.toList()},
      );
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible guardar los choferes asignados.',
      );
    }
  }

  Failure _failure(int? status, String fallback) => switch (status) {
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => const Failure(
      message: 'No tienes permiso para administrar estos choferes.',
      type: FailureType.insufficientPermissions,
    ),
    400 => const Failure(
      message: 'Uno de los choferes seleccionados no es válido.',
      type: FailureType.network,
    ),
    404 => const Failure(
      message: 'El supervisor ya no está disponible.',
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
