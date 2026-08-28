import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/fleet_locations_data_source.dart';
import '../data/dtos/fleet_driver_location_dto.dart';

class FleetLocationsState {
  const FleetLocationsState({
    this.isLoading = false,
    this.drivers = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<FleetDriverLocationDto> drivers;
  final String? errorMessage;
}

final fleetLocationsDataSourceProvider = Provider<FleetLocationsDataSource>((
  ref,
) {
  return FleetLocationsDataSource(ref.watch(backendApiClientProvider));
});

final fleetLocationsProvider =
    NotifierProvider<FleetLocationsNotifier, FleetLocationsState>(
      FleetLocationsNotifier.new,
    );

class FleetLocationsNotifier extends Notifier<FleetLocationsState> {
  @override
  FleetLocationsState build() => const FleetLocationsState();

  Future<void> load() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      state = const FleetLocationsState(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }

    state = FleetLocationsState(isLoading: true, drivers: state.drivers);
    try {
      final drivers = await ref
          .read(fleetLocationsDataSourceProvider)
          .list(sessionToken: session.sessionToken);
      state = FleetLocationsState(drivers: drivers);
    } on Failure catch (error) {
      state = FleetLocationsState(
        drivers: state.drivers,
        errorMessage: error.message,
      );
    } catch (_) {
      state = FleetLocationsState(
        drivers: state.drivers,
        errorMessage: 'No fue posible cargar las ubicaciones de la flota.',
      );
    }
  }
}
