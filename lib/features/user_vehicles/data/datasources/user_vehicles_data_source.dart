import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/user_vehicle_dto.dart';

class UserVehiclesDataSource {
  UserVehiclesDataSource(this._apiClient);
  final ApiClient _apiClient;
  Future<UserVehicleLookupDto> get({
    required String sessionToken,
    required String userId,
  }) async {
    try {
      final data =
          (await _apiClient.get<Map<String, dynamic>>(
            '/api/users/$userId/vehicle',
            bearerToken: sessionToken,
          )).data ??
          {};
      final vehicles = data['vehicles'];
      if (vehicles is! List) throw const FormatException();
      final assignment = data['user_vehicle'];
      return UserVehicleLookupDto(
        assignment: assignment == null
            ? null
            : UserVehicleDto.fromJson(_map(assignment)),
        vehicles: vehicles
            .map((item) => UserVehicleOptionDto.fromJson(_map(item)))
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      throw _failure(error.statusCode);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar el vehículo habitual.',
        type: FailureType.network,
      );
    }
  }

  Future<void> update({
    required String sessionToken,
    required String userId,
    required String? vehicleId,
  }) async {
    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/api/users/$userId/vehicle',
        bearerToken: sessionToken,
        data: {'vehicle_id': vehicleId},
      );
    } on ApiException catch (error) {
      throw _failure(error.statusCode);
    }
  }

  Failure _failure(int? status) => switch (status) {
    400 => const Failure(
      message: 'El chofer o vehículo seleccionado no es válido.',
      type: FailureType.network,
    ),
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => const Failure(
      message: 'No tienes permiso para administrar este vehículo habitual.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'El chofer ya no está disponible.',
      type: FailureType.network,
    ),
    _ => const Failure(
      message: 'No fue posible completar la operación.',
      type: FailureType.network,
    ),
  };
  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}
