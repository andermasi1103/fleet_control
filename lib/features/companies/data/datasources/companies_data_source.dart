import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/company_dto.dart';

class CompaniesDataSource {
  CompaniesDataSource(this._client);

  final SupabaseClient _client;

  Future<List<CompanyDto>> getCompanies({required String sessionToken}) async {
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
          .map((item) => CompanyDto.fromJson(_map(item)))
          .toList(growable: false);
    } on FormatException {
      throw const Failure(
        message: 'No fue posible cargar las empresas.',
        type: FailureType.supabase,
      );
    }
  }

  Future<CompanyDto> createCompany({
    required String sessionToken,
    required String nombre,
  }) async {
    final body = await _invoke(
      'companies-create',
      sessionToken: sessionToken,
      method: HttpMethod.post,
      payload: {'nombre': nombre},
      fallback: 'No fue posible completar la operación.',
    );
    return _companyFrom(body, 'No fue posible completar la operación.');
  }

  Future<CompanyDto> updateCompany({
    required String sessionToken,
    required String id,
    required String nombre,
    required bool isActive,
  }) async {
    final body = await _invoke(
      'companies-update',
      sessionToken: sessionToken,
      method: HttpMethod.patch,
      payload: {'id': id, 'nombre': nombre, 'activo': isActive},
      fallback: 'No fue posible completar la operación.',
    );
    return _companyFrom(body, 'No fue posible completar la operación.');
  }

  CompanyDto _companyFrom(Map<String, dynamic> body, String fallback) {
    try {
      return CompanyDto.fromJson(_map(body['company']));
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
          message: 'No tienes permiso para administrar empresas.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'La empresa ya no está disponible.',
          type: FailureType.supabase,
        );
      case 409:
        return const Failure(
          message: 'Ya existe una empresa con ese nombre.',
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

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Respuesta inválida.');
  }
}
