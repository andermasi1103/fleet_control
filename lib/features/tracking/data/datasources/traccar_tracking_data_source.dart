import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import 'traccar_authorization_provider.dart';

class TraccarTrackingDataSource {
  // ✅ inicializadores formales
  TraccarTrackingDataSource(
    this._dio,
    this._authorizationProvider,
  );

  final Dio _dio;
  final TraccarAuthorizationProvider _authorizationProvider;

  Future<List<Map<String, dynamic>>> getDevices() => _getCollection('/devices');
  Future<List<Map<String, dynamic>>> getPositions() => _getCollection('/positions');
  Future<List<Map<String, dynamic>>> getEvents() => _getCollection('/events');

  Future<List<Map<String, dynamic>>> _getCollection(String path) async {
    try {
      final authorization = await _authorizationProvider.getAuthorizationHeader();
      if (authorization.trim().isEmpty) {
        throw const Failure(
          message: 'La autorización segura de Traccar no está configurada.',
          type: FailureType.configuration,
        );
      }

      final response = await _dio.get<dynamic>(
        path,
        options: Options(
          headers: {'Authorization': authorization},
          extra: const {'skipAuth': true},
        ),
      );

      return _asListOfMaps(response.data);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is! List) {
      throw const Failure(
        message: 'La respuesta de Traccar no tiene el formato esperado.',
        type: FailureType.traccar,
      );
    }

    return data.map((item) {
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
    }).toList(growable: false);
  }

  Failure _mapDioFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const Failure(
          message: 'Traccar tardó demasiado en responder.',
          type: FailureType.timeout,
        );
      case DioExceptionType.connectionError:
        return const Failure(
          message: 'No fue posible conectar con Traccar.',
          type: FailureType.network,
        );
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401) {
          return const Failure(
            message: 'La autorización de Traccar no es válida.',
            type: FailureType.traccar,
          );
        }
        if (error.response?.statusCode == 403) {
          return const Failure(
            message: 'No tienes permisos para consultar Traccar.',
            type: FailureType.insufficientPermissions,
          );
        }
        return const Failure(
          message: 'Traccar no pudo completar la operación.',
          type: FailureType.traccar,
        );
      case DioExceptionType.cancel:
        return const Failure(
          message: 'La consulta a Traccar fue cancelada.',
          type: FailureType.network,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return const Failure(
          message: 'No fue posible procesar la respuesta de Traccar.',
          type: FailureType.traccar,
        );
    }
  }
}
