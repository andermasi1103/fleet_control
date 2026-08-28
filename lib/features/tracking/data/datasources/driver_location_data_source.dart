import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';

class DriverLocationDataSource {
  DriverLocationDataSource(this._client);

  final ApiClient _client;

  Future<void> updateLocation({
    required String sessionToken,
    required Position position,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/driver/location',
        bearerToken: sessionToken,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': _nonNegativeFinite(position.accuracy),
          'speed': _nonNegativeFinite(position.speed),
          'heading': _heading(position.heading),
          'captured_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on ApiException catch (error) {
      throw _failureFor(error.statusCode ?? 0);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible actualizar tu ubicación.',
        type: FailureType.network,
      );
    }
  }

  double? _nonNegativeFinite(double value) {
    if (!value.isFinite || value < 0) {
      return null;
    }
    return value;
  }

  double? _heading(double value) {
    if (!value.isFinite || value < 0 || value >= 360) {
      return null;
    }
    return value;
  }

  Failure _failureFor(int statusCode) {
    switch (statusCode) {
      case 400:
        return const Failure(
          message: 'La ubicación recibida no es válida.',
          statusCode: 400,
          type: FailureType.network,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          statusCode: 401,
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No tienes permiso para informar ubicación.',
          statusCode: 403,
          type: FailureType.insufficientPermissions,
        );
      default:
        return Failure(
          message: 'No fue posible actualizar tu ubicación.',
          statusCode: statusCode,
          type: FailureType.network,
        );
    }
  }
}
