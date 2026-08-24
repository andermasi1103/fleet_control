import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/attendance_dto.dart';
import '../dtos/attendance_status_dto.dart';
import '../dtos/location_dto.dart';

class AttendanceDataSource {
  AttendanceDataSource(this._client);

  final SupabaseClient _client;

  Future<List<LocationDto>> getLocations({required String sessionToken}) async {
    try {
      final response = await _client.functions.invoke(
        'locations-list',
        method: HttpMethod.get,
        headers: {'Authorization': 'Bearer $sessionToken'},
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
    } on FunctionException catch (error) {
      _debugFunctionError('locations-list', error);
      throw _functionFailure(error, 'No fue posible cargar los locales.');
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.supabase,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.supabase,
      );
    }
  }

  Future<AttendanceStatusDto> getAttendanceStatus({
    required String sessionToken,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'attendance-status',
        method: HttpMethod.get,
        headers: {'Authorization': 'Bearer $sessionToken'},
      );
      return AttendanceStatusDto.fromJson(_mapResponse(response.data));
    } on FunctionException catch (error) {
      throw _functionFailure(
        error,
        'No fue posible cargar el estado de asistencia.',
      );
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar el estado de asistencia.',
        type: FailureType.supabase,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible cargar el estado de asistencia.',
        type: FailureType.supabase,
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
      final response = await _client.functions.invoke(
        'attendance-create',
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: {'local_id': localId, 'latitud': latitude, 'longitud': longitude},
      );
      final attendanceValue = _mapResponse(response.data)['attendance'];
      return AttendanceDto.fromJson(_mapResponse(attendanceValue));
    } on FunctionException catch (error) {
      throw _functionFailure(error, 'No fue posible registrar la asistencia.');
    } on Failure {
      rethrow;
    } on FormatException {
      throw const Failure(
        message: 'No fue posible registrar la asistencia.',
        type: FailureType.supabase,
      );
    } catch (_) {
      throw const Failure(
        message: 'No fue posible registrar la asistencia.',
        type: FailureType.supabase,
      );
    }
  }

  Failure _functionFailure(FunctionException error, String fallback) {
    switch (error.status) {
      case 400:
        return const Failure(
          message:
              'No fue posible validar tu ubicación o el local seleccionado.',
          type: FailureType.supabase,
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
          type: FailureType.supabase,
        );
      case 422:
        return const Failure(
          message: 'Estás fuera de la geocerca permitida para este local.',
          type: FailureType.supabase,
        );
      case 500:
        return const Failure(
          message:
              'No fue posible registrar la asistencia. Intenta nuevamente.',
          type: FailureType.supabase,
        );
      default:
        return Failure(message: fallback, type: FailureType.supabase);
    }
  }

  void _debugFunctionError(String endpoint, FunctionException error) {
    if (!kDebugMode) {
      return;
    }
    final details = error.details;
    final code = details is Map ? details['error']?.toString() : null;
    final responseShape = details is Map
        ? 'map keys: ${details.keys.map((key) => key.toString()).join(', ')}'
        : details == null
        ? 'empty'
        : details.runtimeType.toString();
    debugPrint(
      '$endpoint failed: HTTP ${error.status}; code=${code ?? '-'}; response=$responseShape',
    );
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
