import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/user_vehicle_dto.dart';

class UserVehiclesDataSource {
  UserVehiclesDataSource(this._client);

  final SupabaseClient _client;

  Future<UserVehicleLookupDto> get({
    required String sessionToken,
    required String userId,
  }) async {
    final data = await _invoke(
      'user-vehicle-get',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      queryParameters: {'user_id': userId},
    );
    try {
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
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar el vehículo habitual.',
        type: FailureType.supabase,
      );
    }
  }

  Future<void> update({
    required String sessionToken,
    required String userId,
    required String? vehicleId,
  }) async {
    await _invoke(
      'user-vehicle-update',
      sessionToken: sessionToken,
      method: HttpMethod.patch,
      payload: {'user_id': userId, 'vehicle_id': vehicleId},
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    required String sessionToken,
    required HttpMethod method,
    Map<String, dynamic>? payload,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        method: method,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: payload,
        queryParameters: queryParameters,
      );
      return _map(response.data);
    } on FunctionException catch (error) {
      if (kDebugMode) {
        debugPrint('$functionName failed: HTTP ${error.status}');
      }
      throw _failure(error.status);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  Failure _failure(int status) {
    switch (status) {
      case 400:
        return const Failure(
          message: 'El chofer o vehículo seleccionado no es válido.',
          type: FailureType.supabase,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No tienes permiso para administrar este vehículo habitual.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El chofer ya no está disponible.',
          type: FailureType.supabase,
        );
      default:
        return const Failure(
          message: 'No fue posible completar la operación.',
          type: FailureType.supabase,
        );
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}
