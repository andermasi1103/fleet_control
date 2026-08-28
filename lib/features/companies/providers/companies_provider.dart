import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/companies_data_source.dart';
import 'companies_state.dart';

final companiesDataSourceProvider = Provider<CompaniesDataSource>((ref) {
  return CompaniesDataSource(ref.watch(backendApiClientProvider));
});

final companiesProvider = NotifierProvider<CompaniesNotifier, CompaniesState>(
  CompaniesNotifier.new,
);

class CompaniesNotifier extends Notifier<CompaniesState> {
  @override
  CompaniesState build() => const CompaniesState();

  Future<void> loadCompanies() async {
    final token = _sessionToken();
    if (token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final companies = await ref
          .read(companiesDataSourceProvider)
          .getCompanies(sessionToken: token);
      state = CompaniesState(companies: companies);
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar las empresas.',
      );
    }
  }

  Future<void> refresh() => loadCompanies();

  Future<bool> createCompany({required String nombre}) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await ref
          .read(companiesDataSourceProvider)
          .createCompany(sessionToken: token, nombre: nombre);
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Empresa creada correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  Future<bool> updateCompany({
    required String id,
    required String nombre,
    required bool isActive,
  }) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await ref
          .read(companiesDataSourceProvider)
          .updateCompany(
            sessionToken: token,
            id: id,
            nombre: nombre,
            isActive: isActive,
          );
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Empresa actualizada correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  bool _sessionFailure() {
    state = state.copyWith(
      errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
    );
    return false;
  }

  String? _sessionToken() {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      return null;
    }
    return session.sessionToken;
  }
}
