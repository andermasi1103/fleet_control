import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../dtos/vehicle_dto.dart';

class VehiclesDataSource {
  VehiclesDataSource(this._client);
  final SupabaseClient _client;
  Future<List<VehicleDto>> getVehicles({required String sessionToken}) async {
    final response = await _invoke(
      'vehicles-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      fallback: 'No fue posible cargar los vehículos.',
    );
    final values = response['vehicles'];
    if (values is! List) {
      throw const Failure(
        message: 'No fue posible cargar los vehículos.',
        type: FailureType.supabase,
      );
    }
    try {
      return values
          .map((value) => VehicleDto.fromJson(_map(value)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los vehículos.',
        type: FailureType.supabase,
      );
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
  }) => _save(
    'vehicles-create',
    sessionToken: sessionToken,
    method: HttpMethod.post,
    payload: {
      'empresa_id': companyId,
      'patente': plate,
      'marca': brand,
      'modelo': model,
      'tipo_vehiculo': vehicleType,
      'anio': year,
      'descripcion': description,
    },
    fallback: 'No fue posible completar la operación.',
  );
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
  }) => _save(
    'vehicles-update',
    sessionToken: sessionToken,
    method: HttpMethod.patch,
    payload: {
      'id': id,
      'empresa_id': companyId,
      'patente': plate,
      'marca': brand,
      'modelo': model,
      'tipo_vehiculo': vehicleType,
      'anio': year,
      'descripcion': description,
      'activo': isActive,
    },
    fallback: 'No fue posible completar la operación.',
  );
  Future<VehicleDto> _save(
    String functionName, {
    required String sessionToken,
    required HttpMethod method,
    required Map<String, dynamic> payload,
    required String fallback,
  }) async {
    final response = await _invoke(
      functionName,
      sessionToken: sessionToken,
      method: method,
      payload: payload,
      fallback: fallback,
    );
    try {
      return VehicleDto.fromJson(_map(response['vehicle']));
    } on FormatException {
      throw Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    required String sessionToken,
    required HttpMethod method,
    required String fallback,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        method: method,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: payload,
      );
      return _map(response.data);
    } on FunctionException catch (exception) {
      if (kDebugMode) {
        final details = exception.details;
        final code = details is Map ? details['error'] : null;
        final keys = details is Map ? details.keys.join(', ') : 'empty';
        debugPrint(
          '$functionName failed: HTTP ${exception.status}; code=${code ?? '-'}; response=$keys',
        );
      }
      throw _failure(exception.status, fallback);
    } catch (_) {
      throw Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Failure _failure(int status, String fallback) {
    switch (status) {
      case 400:
        return const Failure(
          message: 'Revisa los datos ingresados.',
          type: FailureType.supabase,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No tienes permiso para administrar vehículos.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El vehículo o empresa ya no está disponible.',
          type: FailureType.supabase,
        );
      case 409:
        return const Failure(
          message:
              'Ya existe un vehículo con esa patente para la empresa seleccionada.',
          type: FailureType.supabase,
        );
      default:
        return Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException();
  }
}
