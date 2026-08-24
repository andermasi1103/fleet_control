import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../../../attendance/data/dtos/location_dto.dart';
import '../dtos/company_option_dto.dart';
import '../dtos/location_import_dto.dart';

class LocationsDataSource {
  LocationsDataSource(this._client);

  final SupabaseClient _client;

  Future<List<LocationDto>> getLocations({required String sessionToken}) async {
    final body = await _invoke(
      'locations-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      fallback: 'No fue posible cargar los locales.',
    );
    final locations = body['locations'];
    if (locations is! List) {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.supabase,
      );
    }
    try {
      return locations
          .map((item) => LocationDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar los locales.',
        type: FailureType.supabase,
      );
    }
  }

  Future<List<CompanyOptionDto>> getCompanies({
    required String sessionToken,
  }) async {
    final body = await _invoke(
      'companies-list',
      sessionToken: sessionToken,
      method: HttpMethod.get,
      fallback: 'No fue posible cargar las empresas.',
    );
    final companies = body['companies'];
    if (companies is! List) {
      throw const Failure(
        message: 'No fue posible cargar las empresas.',
        type: FailureType.supabase,
      );
    }
    try {
      return companies
          .map((item) => CompanyOptionDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar las empresas.',
        type: FailureType.supabase,
      );
    }
  }

  Future<LocationDto> createLocation({
    required String sessionToken,
    required String companyId,
    required String nombre,
    required String? direccion,
    required double latitude,
    required double longitude,
    required double radioMeters,
  }) async {
    final body = await _invoke(
      'locations-create',
      sessionToken: sessionToken,
      method: HttpMethod.post,
      payload: {
        'empresa_id': companyId,
        'nombre': nombre,
        'direccion': direccion,
        'latitud': latitude,
        'longitud': longitude,
        'radio_metros': radioMeters,
      },
      fallback: 'No fue posible completar la operación.',
    );
    try {
      return LocationDto.fromJson(_map(body['location']));
    } on FormatException {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  Future<LocationDto> updateLocation({
    required String sessionToken,
    required String id,
    required String companyId,
    required String nombre,
    required String? direccion,
    required double latitude,
    required double longitude,
    required double radioMeters,
    required bool isActive,
  }) async {
    final body = await _invoke(
      'locations-update',
      sessionToken: sessionToken,
      method: HttpMethod.patch,
      payload: {
        'id': id,
        'empresa_id': companyId,
        'nombre': nombre,
        'direccion': direccion,
        'latitud': latitude,
        'longitud': longitude,
        'radio_metros': radioMeters,
        'activo': isActive,
      },
      fallback: 'No fue posible completar la operación.',
    );
    try {
      return LocationDto.fromJson(_map(body['location']));
    } on FormatException {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  Future<int> importLocations({
    required String sessionToken,
    required String companyId,
    required List<LocationImportRow> locations,
  }) async {
    final body = await _invoke(
      'locations-import',
      sessionToken: sessionToken,
      method: HttpMethod.post,
      payload: {
        'empresa_id': companyId,
        'locations': locations.map((location) => location.toJson()).toList(),
      },
      fallback: 'No fue posible importar los locales.',
    );
    final count = body['imported_count'];
    if (count is! num) {
      throw const Failure(
        message: 'El archivo contiene filas inválidas o duplicadas.',
        type: FailureType.supabase,
      );
    }
    return count.toInt();
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
    } on FunctionException catch (error) {
      throw _failureFor(error.status, fallback);
    } on Failure {
      rethrow;
    } on FormatException {
      throw Failure(message: fallback, type: FailureType.supabase);
    } catch (_) {
      throw Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Failure _failureFor(int status, String fallback) {
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
          message: 'No tienes permiso para administrar locales.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El local o empresa ya no está disponible.',
          type: FailureType.supabase,
        );
      case 409:
        return const Failure(
          message: 'Ya existe un local con esos datos.',
          type: FailureType.supabase,
        );
      case 500:
        return const Failure(
          message: 'No fue posible completar la operación.',
          type: FailureType.supabase,
        );
      default:
        return Failure(message: fallback, type: FailureType.supabase);
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Respuesta inválida.');
  }
}
