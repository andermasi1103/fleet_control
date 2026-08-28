import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../attendance/data/dtos/location_dto.dart';
import '../data/datasources/locations_data_source.dart';
import '../data/dtos/company_option_dto.dart';
import '../data/dtos/location_import_dto.dart';
import 'locations_state.dart';

final locationsDataSourceProvider = Provider<LocationsDataSource>((ref) {
  return LocationsDataSource(ref.watch(backendApiClientProvider));
});

final locationsProvider = NotifierProvider<LocationsNotifier, LocationsState>(
  LocationsNotifier.new,
);

class LocationsNotifier extends Notifier<LocationsState> {
  @override
  LocationsState build() => const LocationsState();

  Future<void> load() async {
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
      final source = ref.read(locationsDataSourceProvider);
      final results = await Future.wait<Object>([
        source.getLocations(sessionToken: token),
        source.getCompanies(sessionToken: token),
      ]);
      state = LocationsState(
        locations: results[0] as List<LocationDto>,
        companies: results[1] as List<CompanyOptionDto>,
      );
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar los locales.',
      );
    }
  }

  Future<bool> createLocation({
    required String companyId,
    required String nombre,
    required String? direccion,
    required double latitude,
    required double longitude,
    required double radioMeters,
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
          .read(locationsDataSourceProvider)
          .createLocation(
            sessionToken: token,
            companyId: companyId,
            nombre: nombre,
            direccion: direccion,
            latitude: latitude,
            longitude: longitude,
            radioMeters: radioMeters,
          );
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Local creado correctamente.',
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

  Future<bool> updateLocation({
    required String id,
    required String companyId,
    required String nombre,
    required String? direccion,
    required double latitude,
    required double longitude,
    required double radioMeters,
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
          .read(locationsDataSourceProvider)
          .updateLocation(
            sessionToken: token,
            id: id,
            companyId: companyId,
            nombre: nombre,
            direccion: direccion,
            latitude: latitude,
            longitude: longitude,
            radioMeters: radioMeters,
            isActive: isActive,
          );
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Local actualizado correctamente.',
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

  Future<int?> importLocations({
    required String companyId,
    required List<LocationImportRow> locations,
  }) async {
    final token = _sessionToken();
    if (token == null) {
      _sessionFailure();
      return null;
    }
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final imported = await ref
          .read(locationsDataSourceProvider)
          .importLocations(
            sessionToken: token,
            companyId: companyId,
            locations: locations,
          );
      state = state.copyWith(
        isSaving: false,
        successMessage: '$imported locales importados correctamente.',
      );
      return imported;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible importar los locales.',
      );
      return null;
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
