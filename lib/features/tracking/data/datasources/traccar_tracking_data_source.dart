import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';

class TraccarTrackingDataSource {
  TraccarTrackingDataSource(this._client, this._sessionToken);

  final ApiClient _client;
  final String Function() _sessionToken;

  Future<List<Map<String, dynamic>>> getDevices() => _getCollection('/devices');
  Future<List<Map<String, dynamic>>> getPositions() =>
      _getCollection('/positions');
  Future<List<Map<String, dynamic>>> getEvents() => _getCollection('/events');

  Future<List<Map<String, dynamic>>> _getCollection(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/tracking$path',
        bearerToken: _sessionToken(),
      );
      final data = response.data;
      if (data == null) {
        throw const Failure(
          message: 'La respuesta de Traccar no tiene el formato esperado.',
          type: FailureType.traccar,
        );
      }

      return _asListOfMaps(data['items']);
    } on ApiException catch (error) {
      throw _mapApiFailure(error);
    }
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is! List) {
      throw const Failure(
        message: 'La respuesta de Traccar no tiene el formato esperado.',
        type: FailureType.traccar,
      );
    }

    return data
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }

          throw const Failure(
            message: 'La respuesta de Traccar contiene un registro inválido.',
            type: FailureType.traccar,
          );
        })
        .toList(growable: false);
  }

  Failure _mapApiFailure(ApiException error) {
    if (error.statusCode == 401) {
      return const Failure(
        message: 'Sesión inválida o expirada.',
        type: FailureType.sessionExpired,
      );
    }
    if (error.statusCode == 403) {
      return const Failure(
        message: 'No tienes permisos para consultar el seguimiento.',
        type: FailureType.insufficientPermissions,
      );
    }
    if (error.statusCode == 503) {
      return const Failure(
        message: 'Seguimiento no disponible.',
        type: FailureType.traccar,
      );
    }
    return const Failure(
      message: 'No fue posible consultar el seguimiento.',
      type: FailureType.network,
    );
  }
}
