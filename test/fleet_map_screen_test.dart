import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/fleet_tracking/presentation/fleet_map_screen.dart';
import 'package:fleet_control/features/fleet_tracking/providers/fleet_locations_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('el mapa renderiza el estado vacío sin ubicaciones', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/fleet-map',
      routes: [
        GoRoute(path: '/fleet-map', builder: (_, _) => const FleetMapScreen()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_UnauthenticatedSessionNotifier.new),
          fleetLocationsProvider.overrideWith(_EmptyFleetLocationsNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Mapa de Flota'), findsOneWidget);
    expect(
      find.text('No hay ubicaciones disponibles para mostrar.'),
      findsOneWidget,
    );
  });
}

class _UnauthenticatedSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState.unauthenticated();
}

class _EmptyFleetLocationsNotifier extends FleetLocationsNotifier {
  @override
  FleetLocationsState build() => const FleetLocationsState();

  @override
  Future<void> loadMap() async {}
}
