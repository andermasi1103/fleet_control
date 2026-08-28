import 'package:flutter/foundation.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/attendance_dto.dart';
import '../dtos/attendance_status_dto.dart';
import '../dtos/location_dto.dart';

class AttendanceDataSource {
  AttendanceDataSource(this._client);

  final ApiClient _client;

  Future<List<LocationDto>> getLocations({required String sessionToken}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/locations',
        bearerToken: sessionToken,
      );
      final locations = _mapResponse(response.data)['locations'];
      if (locations is! List) {
        throw const FormatException('Respuesta de locales inválida.');
      }
      final parsedLocations = locations
          .map((item) => LocationDto.fromJson(_mapResponse(item)))
          .toList(growable: false);
      if (kDebugMode) {
        debugPrint('locations-list count=${parsedLocations.length}');
        for (final location in parsedLocations) {
          debugPrint(
            'locations-list id=${location.id} nombre=${location.nombre}',
          );
        }
      }
      return parsedLocations;
    } on ApiException catch (error) {
      throw _apiFailure(error.statusCode, 'No fue posible cargar los locales.');
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.backend,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.backend,
      );
    }
  }

  Future<AttendanceStatusDto> getAttendanceStatus({
    required String sessionToken,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/api/attendance/status',
        bearerToken: sessionToken,
      );
      return AttendanceStatusDto.fromJson(_mapResponse(response.data));
    } on ApiException catch (error) {
      throw _apiFailure(
        error.statusCode,
        'No fue posible cargar el estado de asistencia.',
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar el estado de asistencia.',
        type: FailureType.backend,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar el estado de asistencia.',
        type: FailureType.backend,
      );
    }
  }

  Future<AttendanceDto> createAttendance({
    required String sessionToken,
    required String localId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/api/attendance',
        bearerToken: sessionToken,
        data: {'local_id': localId, 'latitud': latitude, 'longitud': longitude},
      );
      final attendanceValue = _mapResponse(response.data)['attendance'];
      return AttendanceDto.fromJson(_mapResponse(attendanceValue));
    } on ApiException catch (error) {
      throw _apiFailure(
        error.statusCode,
        'No fue posible registrar la asistencia.',
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible registrar la asistencia.',
        type: FailureType.backend,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible registrar la asistencia.',
        type: FailureType.backend,
      );
    }
  }

  Failure _apiFailure(int? status, String fallback) {
    switch (status) {
      case 400:
        return const Failure(
          message:
              'No fue posible validar tu ubicación o el local seleccionado.',
          type: FailureType.backend,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No tienes permiso para realizar esta operación.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El local seleccionado no está disponible.',
          type: FailureType.backend,
        );
      case 422:
        return const Failure(
          message: 'Estás fuera de la geocerca permitida para este local.',
          type: FailureType.backend,
        );
      case 500:
        return const Failure(
          message:
              'No fue posible registrar la asistencia. Intenta nuevamente.',
          type: FailureType.backend,
        );
      default:
        return Failure(message: fallback, type: FailureType.backend);
    }
  }

  Map<String, dynamic> _mapResponse(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Respuesta de asistencia inválida.');
  }
}
