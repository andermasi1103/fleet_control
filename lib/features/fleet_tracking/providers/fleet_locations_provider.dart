import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../companies/data/datasources/companies_data_source.dart';
import '../../companies/data/dtos/company_dto.dart';
import '../../locations/data/datasources/locations_data_source.dart';
import '../../attendance/data/dtos/location_dto.dart';
import '../data/datasources/fleet_locations_data_source.dart';
import '../data/dtos/fleet_driver_location_dto.dart';

class FleetLocationsState {
  const FleetLocationsState({
    this.isLoading = false,
    this.isStaticLoading = false,
    this.drivers = const [],
    this.locations = const [],
    this.companies = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final bool isStaticLoading;
  final List<FleetDriverLocationDto> drivers;
  final List<LocationDto> locations;
  final List<CompanyDto> companies;
  final String? errorMessage;
}

final fleetLocationsDataSourceProvider = Provider<FleetLocationsDataSource>((
  ref,
) {
  return FleetLocationsDataSource(ref.watch(backendApiClientProvider));
});

final fleetMapLocationsDataSourceProvider = Provider<LocationsDataSource>((
  ref,
) {
  return LocationsDataSource(ref.watch(backendApiClientProvider));
});

final fleetMapCompaniesDataSourceProvider = Provider<CompaniesDataSource>((
  ref,
) {
  return CompaniesDataSource(ref.watch(backendApiClientProvider));
});

final fleetLocationsProvider =
    NotifierProvider<FleetLocationsNotifier, FleetLocationsState>(
      FleetLocationsNotifier.new,
    );

class FleetLocationsNotifier extends Notifier<FleetLocationsState> {
  Future<void>? _inFlight;
  Future<void>? _staticInFlight;

  @override
  FleetLocationsState build() => const FleetLocationsState();

  Future<void> load() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> loadMap() => Future.wait([load(), loadStatic()]);

  Future<void> refreshAll() => Future.wait([load(), loadStatic()]);

  Future<void> loadStatic() {
    return _staticInFlight ??= _loadStatic().whenComplete(
      () => _staticInFlight = null,
    );
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      state = FleetLocationsState(
        locations: state.locations,
        companies: state.companies,
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }

    state = FleetLocationsState(
      isLoading: true,
      isStaticLoading: state.isStaticLoading,
      drivers: state.drivers,
      locations: state.locations,
      companies: state.companies,
    );
    try {
      final drivers = await ref
          .read(fleetLocationsDataSourceProvider)
          .list(sessionToken: session.sessionToken);
      state = FleetLocationsState(
        isStaticLoading: state.isStaticLoading,
        drivers: drivers,
        locations: state.locations,
        companies: state.companies,
      );
    } on Failure catch (error) {
      state = FleetLocationsState(
        isStaticLoading: state.isStaticLoading,
        drivers: state.drivers,
        locations: state.locations,
        companies: state.companies,
        errorMessage: error.message,
      );
    } catch (_) {
      state = FleetLocationsState(
        isStaticLoading: state.isStaticLoading,
        drivers: state.drivers,
        locations: state.locations,
        companies: state.companies,
        errorMessage: 'No fue posible cargar las ubicaciones de la flota.',
      );
    }
  }

  Future<void> _loadStatic() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      state = FleetLocationsState(
        drivers: state.drivers,
        locations: state.locations,
        companies: state.companies,
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }

    state = FleetLocationsState(
      isLoading: state.isLoading,
      isStaticLoading: true,
      drivers: state.drivers,
      locations: state.locations,
      companies: state.companies,
    );
    try {
      final result = await Future.wait<Object>([
        ref
            .read(fleetMapLocationsDataSourceProvider)
            .getMapLocations(sessionToken: session.sessionToken),
        ref
            .read(fleetMapCompaniesDataSourceProvider)
            .getCompanies(sessionToken: session.sessionToken),
      ]);
      state = FleetLocationsState(
        isLoading: state.isLoading,
        drivers: state.drivers,
        locations: result[0] as List<LocationDto>,
        companies: result[1] as List<CompanyDto>,
      );
    } on Failure catch (error) {
      state = FleetLocationsState(
        isLoading: state.isLoading,
        drivers: state.drivers,
        locations: state.locations,
        companies: state.companies,
        errorMessage: error.message,
      );
    } catch (_) {
      state = FleetLocationsState(
        isLoading: state.isLoading,
        drivers: state.drivers,
        locations: state.locations,
        companies: state.companies,
        errorMessage: 'No fue posible cargar los puntos de venta.',
      );
    }
  }
}
