import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../attendance/data/dtos/location_dto.dart';
import '../dtos/company_option_dto.dart';
import '../dtos/location_import_dto.dart';

class LocationsDataSource {
  LocationsDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<List<LocationDto>> getLocations({
    required String sessionToken,
  }) async => _list(
    '/api/locations',
    sessionToken,
    'locations',
    (json) => LocationDto.fromJson(json),
    'No fue posible cargar los locales.',
  );
  Future<List<CompanyOptionDto>> getCompanies({
    required String sessionToken,
  }) async => _list(
    '/api/companies',
    sessionToken,
    'companies',
    (json) => CompanyOptionDto.fromJson(json),
    'No fue posible cargar las empresas.',
  );
  Future<LocationDto> createLocation({
    required String sessionToken,
    required String companyId,
    required String nombre,
    required String? direccion,
    required double latitude,
    required double longitude,
    required double radioMeters,
  }) => _save('/api/locations', sessionToken, {
    'empresa_id': companyId,
    'nombre': nombre,
    'direccion': direccion,
    'latitud': latitude,
    'longitud': longitude,
    'radio_metros': radioMeters,
  });
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
  }) => _save('/api/locations/$id', sessionToken, {
    'empresa_id': companyId,
    'nombre': nombre,
    'direccion': direccion,
    'latitud': latitude,
    'longitud': longitude,
    'radio_metros': radioMeters,
    'activo': isActive,
  }, patch: true);

  Future<int> importLocations({
    required String sessionToken,
    required String companyId,
    required List<LocationImportRow> locations,
  }) async {
    try {
      final data = (await _apiClient.post<Map<String, dynamic>>(
        '/api/locations/import',
        bearerToken: sessionToken,
        data: {
          'empresa_id': companyId,
          'locations': locations.map((location) => location.toJson()).toList(),
        },
      )).data;
      final count = data?['imported_count'];
      if (count is! num) {
        return _invalid('El archivo contiene filas inválidas o duplicadas.');
      }
      return count.toInt();
    } on ApiException catch (error) {
      throw _failure(error.statusCode, 'No fue posible importar los locales.');
    }
  }

  Future<LocationDto> _save(
    String path,
    String token,
    Map<String, dynamic> data, {
    bool patch = false,
  }) async {
    try {
      final response = patch
          ? await _apiClient.patch<Map<String, dynamic>>(
              path,
              data: data,
              bearerToken: token,
            )
          : await _apiClient.post<Map<String, dynamic>>(
              path,
              data: data,
              bearerToken: token,
            );
      return LocationDto.fromJson(_map(response.data?['location']));
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible completar la operación.',
      );
    } on FormatException {
      return _invalid('No fue posible completar la operación.');
    }
  }

  Future<List<T>> _list<T>(
    String path,
    String token,
    String key,
    T Function(Map<String, dynamic>) parse,
    String fallback,
  ) async {
    try {
      final values = (await _apiClient.get<Map<String, dynamic>>(
        path,
        bearerToken: token,
      )).data?[key];
      if (values is! List) {
        return _invalid(fallback);
      }
      return values.map((item) => parse(_map(item))).toList(growable: false);
    } on ApiException catch (error) {
      throw _failure(error.statusCode, fallback);
    } on FormatException {
      return _invalid(fallback);
    }
  }

  Never _invalid(String message) =>
      throw Failure(message: message, type: FailureType.network);
  Failure _failure(int? status, String fallback) => switch (status) {
    400 => const Failure(
      message: 'Revisa los datos ingresados.',
      type: FailureType.network,
    ),
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => const Failure(
      message: 'No tienes permiso para administrar locales.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'El local o empresa ya no está disponible.',
      type: FailureType.network,
    ),
    409 => const Failure(
      message: 'Ya existe un local con esos datos.',
      type: FailureType.network,
    ),
    _ => Failure(message: fallback, type: FailureType.network),
  };
  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException();
  }
}
