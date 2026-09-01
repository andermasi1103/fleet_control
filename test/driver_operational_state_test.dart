import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_control/features/tracking/domain/driver_operational_state.dart';
import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';

void main() {
  group('driver operational state', () {
    test('without a driver state, tracking stays idle', () {
      expect(trackingProfileForOperationalState(null), TrackingProfile.idle);
    });

    test('available driver uses the available tracking profile', () {
      expect(
        trackingProfileForOperationalState(DriverOperationalState.available),
        TrackingProfile.available,
      );
    });

    test('assigned management remains on the available profile', () {
      expect(
        trackingProfileForOperationalState(DriverOperationalState.assigned),
        TrackingProfile.available,
      );
    });

    for (final status in ['aceptado', 'en_camino', 'en_gestion']) {
      test('$status uses the active-trip profile', () {
        expect(
          trackingProfileForOperationalState(
            driverOperationalStateFromManagementStatus(status),
          ),
          TrackingProfile.activeTrip,
        );
      });
    }

    for (final status in ['completado', 'cancelado']) {
      test('$status returns to the available profile', () {
        expect(
          trackingProfileForOperationalState(
            driverOperationalStateFromManagementStatus(status),
          ),
          TrackingProfile.available,
        );
      });
    }

    test('active management takes priority over assigned management', () {
      expect(
        driverOperationalStateFromManagementStatuses(['asignado', 'en_camino']),
        DriverOperationalState.enRoute,
      );
    });

    test(
      'available-to-active and active-to-available transitions change profile',
      () {
        final available = trackingProfileForOperationalState(
          DriverOperationalState.available,
        );
        final active = trackingProfileForOperationalState(
          DriverOperationalState.accepted,
        );

        expect(available, isNot(active));
        expect(
          trackingProfileForOperationalState(DriverOperationalState.available),
          available,
        );
      },
    );
  });
}
