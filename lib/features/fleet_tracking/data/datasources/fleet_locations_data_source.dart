import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/fleet_driver_location_dto.dart';

class FleetLocationsDataSource {
  FleetLocationsDataSource(this._client);

  final ApiClient _client;

  Future<List<FleetDriverLocationDto>> list({
    required String sessionToken,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/fleet/locations',
        bearerToken: sessionToken,
      );
      final data = _map(response.data);
      final drivers = data['drivers'];
      if (drivers is! List) {
        throw const FormatException('Respuesta de mapa de flota inválida.');
      }

      return drivers
          .map((driver) => FleetDriverLocationDto.fromJson(_map(driver)))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw _failureFor(error.statusCode);
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible interpretar las ubicaciones de la flota.',
        type: FailureType.backend,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar las ubicaciones de la flota.',
        type: FailureType.network,
      );
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Respuesta de mapa de flota inválida.');
  }

  Failure _failureFor(int? statusCode) {
    switch (statusCode) {
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          statusCode: 401,
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No fue posible cargar las ubicaciones de la flota.',
          statusCode: 403,
          type: FailureType.insufficientPermissions,
        );
      default:
        return Failure(
          message: 'No fue posible cargar las ubicaciones de la flota.',
          statusCode: statusCode,
          type: FailureType.backend,
        );
    }
  }
}
