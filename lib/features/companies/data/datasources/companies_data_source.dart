import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/company_dto.dart';

class CompaniesDataSource {
  CompaniesDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CompanyDto>> getCompanies({required String sessionToken}) async {
    final body = await _get(
      '/api/companies',
      sessionToken,
      'No fue posible cargar las empresas.',
    );
    final companies = body['companies'];
    if (companies is! List) {
      return _invalid('No fue posible cargar las empresas.');
    }
    try {
      return companies
          .map((item) => CompanyDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      return _invalid('No fue posible cargar las empresas.');
    }
  }

  Future<CompanyDto> createCompany({
    required String sessionToken,
    required String nombre,
    String localMarkerIcon = 'storefront',
    String? localMarkerColor,
  }) => _save('/api/companies', sessionToken, {
    'nombre': nombre,
    'local_marker_icon': localMarkerIcon,
    'local_marker_color': localMarkerColor,
  });

  Future<CompanyDto> updateCompany({
    required String sessionToken,
    required String id,
    required String nombre,
    required bool isActive,
    String localMarkerIcon = 'storefront',
    String? localMarkerColor,
  }) => _save('/api/companies/$id', sessionToken, {
    'nombre': nombre,
    'activo': isActive,
    'local_marker_icon': localMarkerIcon,
    'local_marker_color': localMarkerColor,
  }, patch: true);

  Future<CompanyDto> _save(
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
      return CompanyDto.fromJson(_map(response.data?['company']));
    } on ApiException catch (error) {
      throw _failure(
        error.statusCode,
        'No fue posible completar la operación.',
      );
    } on FormatException {
      return _invalid('No fue posible completar la operación.');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path,
    String token,
    String fallback,
  ) async {
    try {
      return _map(
        (await _apiClient.get<Map<String, dynamic>>(
          path,
          bearerToken: token,
        )).data,
      );
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
      message: 'No tienes permiso para administrar empresas.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'La empresa ya no está disponible.',
      type: FailureType.network,
    ),
    409 => const Failure(
      message: 'Ya existe una empresa con ese nombre.',
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
