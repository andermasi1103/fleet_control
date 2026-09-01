import 'package:fleet_control/features/fleet_tracking/data/dtos/fleet_driver_location_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a newer fleet location without retaining old values', () {
    final oldLocation = FleetDriverLocationDto.fromJson({
      'driver_user_id': 'driver-1',
      'driver_name': 'Ana',
      'driver_username': 'ana',
      'connection_status': 'online',
      'operational_status': 'disponible',
      'latitude': -25.2867,
      'longitude': -57.6470,
      'accuracy': 20,
      'speed': 0,
      'heading': 0,
      'captured_at': '2030-01-01T12:00:00.000Z',
      'last_seen_at': '2030-01-01T12:00:00.000Z',
    });
    final newLocation = FleetDriverLocationDto.fromJson({
      'driver_user_id': 'driver-1',
      'driver_name': 'Ana',
      'driver_username': 'ana',
      'connection_status': 'online',
      'operational_status': 'disponible',
      'latitude': -25.2800,
      'longitude': -57.6400,
      'accuracy': 8,
      'speed': 3.5,
      'heading': 90,
      'captured_at': '2030-01-01T12:02:00.000Z',
      'last_seen_at': '2030-01-01T12:02:00.000Z',
    });

    expect(newLocation.latitude, isNot(oldLocation.latitude));
    expect(newLocation.longitude, isNot(oldLocation.longitude));
    expect(newLocation.accuracyMeters, 8);
    expect(newLocation.speedMps, 3.5);
    expect(newLocation.headingDegrees, 90);
    expect(newLocation.capturedAt!.isAfter(oldLocation.capturedAt!), isTrue);
    expect(newLocation.lastSeenAt!.isAfter(oldLocation.lastSeenAt!), isTrue);
  });
}
