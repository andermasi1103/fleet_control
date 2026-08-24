import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';

class DriverLocationDataSource {
  DriverLocationDataSource(this._client);

  final SupabaseClient _client;

  Future<void> updateLocation({
    required String sessionToken,
    required Position position,
  }) async {
    try {
      await _client.functions.invoke(
        'driver-location-update',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': _nonNegativeFinite(position.accuracy),
          'speed': _nonNegativeFinite(position.speed),
          'heading': _heading(position.heading),
          'captured_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on FunctionException catch (error) {
      if (kDebugMode) {
        debugPrint('driver-location update failed: status=${error.status}');
      }
      throw _failureFor(error.status);
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
          type: FailureType.supabase,
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
          type: FailureType.supabase,
        );
    }
  }
}
