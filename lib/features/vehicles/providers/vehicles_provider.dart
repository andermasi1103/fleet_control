import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../companies/providers/companies_provider.dart'
    show companiesDataSourceProvider;
import '../data/datasources/vehicles_data_source.dart';
import 'vehicles_state.dart';

final vehiclesDataSourceProvider = Provider<VehiclesDataSource>(
  (ref) => VehiclesDataSource(ref.watch(backendApiClientProvider)),
);
final vehiclesProvider = NotifierProvider<VehiclesNotifier, VehiclesState>(
  VehiclesNotifier.new,
);

class VehiclesNotifier extends Notifier<VehiclesState> {
  @override
  VehiclesState build() => const VehiclesState();
  String? get _token {
    final session = ref.read(sessionProvider).session;
    return session == null || session.isExpired || session.sessionToken.isEmpty
        ? null
        : session.sessionToken;
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final source = ref.read(vehiclesDataSourceProvider);
      final vehicles = await source.getVehicles(sessionToken: token);
      final companies = await ref
          .read(companiesDataSourceProvider)
          .getCompanies(sessionToken: token);
      state = VehiclesState(
        vehicles: vehicles,
        companies: companies,
        searchQuery: state.searchQuery,
      );
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar los vehículos.',
      );
    }
  }

  Future<void> refresh() => load();
  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);
  Future<bool> createVehicle({
    required String companyId,
    required String plate,
    String? brand,
    String? model,
    String? vehicleType,
    int? year,
    String? description,
  }) => _save(
    () => ref
        .read(vehiclesDataSourceProvider)
        .createVehicle(
          sessionToken: _token!,
          companyId: companyId,
          plate: plate,
          brand: brand,
          model: model,
          vehicleType: vehicleType,
          year: year,
          description: description,
        ),
  );
  Future<bool> updateVehicle({
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
    () => ref
        .read(vehiclesDataSourceProvider)
        .updateVehicle(
          sessionToken: _token!,
          id: id,
          companyId: companyId,
          plate: plate,
          brand: brand,
          model: model,
          vehicleType: vehicleType,
          year: year,
          description: description,
          isActive: isActive,
        ),
  );
  Future<bool> _save(Future<void> Function() operation) async {
    if (_token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return false;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await operation();
      state = state.copyWith(isSaving: false);
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
}
