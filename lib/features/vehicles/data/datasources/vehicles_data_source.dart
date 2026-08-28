import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/vehicle_dto.dart';

class VehiclesDataSource {
  VehiclesDataSource(this._apiClient);
  final ApiClient _apiClient;
  Future<List<VehicleDto>> getVehicles({required String sessionToken}) async {
    try {
      final values = (await _apiClient.get<Map<String, dynamic>>(
        '/api/vehicles',
        bearerToken: sessionToken,
      )).data?['vehicles'];
      if (values is! List) {
        return _invalid('No fue posible cargar los vehículos.');
      }
      return values
          .map((item) => VehicleDto.fromJson(_map(item)))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw _failure(error.statusCode, 'No fue posible cargar los vehículos.');
    } on FormatException {
      return _invalid('No fue posible cargar los vehículos.');
    }
  }

  Future<VehicleDto> createVehicle({
    required String sessionToken,
    required String companyId,
    required String plate,
    String? brand,
    String? model,
    String? vehicleType,
    int? year,
    String? description,
  }) => _save('/api/vehicles', sessionToken, {
    'empresa_id': companyId,
    'patente': plate,
    'marca': brand,
    'modelo': model,
    'tipo_vehiculo': vehicleType,
    'anio': year,
    'descripcion': description,
  });
  Future<VehicleDto> updateVehicle({
    required String sessionToken,
    required String id,
    required String companyId,
    required String plate,
    String? brand,
    String? model,
    String? vehicleType,
    int? year,
    String? description,
    required bool isActive,
  }) => _save('/api/vehicles/$id', sessionToken, {
    'empresa_id': companyId,
    'patente': plate,
    'marca': brand,
    'modelo': model,
    'tipo_vehiculo': vehicleType,
    'anio': year,
    'descripcion': description,
    'activo': isActive,
  }, patch: true);
  Future<VehicleDto> _save(
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
      return VehicleDto.fromJson(_map(response.data?['vehicle']));
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible completar la operación.',
      );
    } on FormatException {
      return _invalid('No fue posible completar la operación.');
    }
  }

  Never _invalid(String message) =>
      throw Failure(message: message, type: FailureType.network);
  Failure _failure(int? status, String fallback) => switch (status) {
    400 => const Failure(
      message: 'Revisa los datos ingresados.',
      type: FailureType.network,
    ),
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => const Failure(
      message: 'No tienes permiso para administrar vehículos.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'El vehículo o empresa ya no está disponible.',
      type: FailureType.network,
    ),
    409 => const Failure(
      message:
          'Ya existe un vehículo con esa patente para la empresa seleccionada.',
      type: FailureType.network,
    ),
    _ => Failure(message: fallback, type: FailureType.network),
  };
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
