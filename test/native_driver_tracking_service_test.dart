import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:fleet_control/features/tracking/services/native_driver_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native tracking start request contains only required runtime data', () {
    const request = NativeDriverTrackingStartRequest(
      sessionToken: 'session-token',
      backendApiBaseUrl: 'https://api.example.test/',
      profile: TrackingProfile.activeTrip,
    );

    expect(request.toMethodArguments(), {
      'sessionToken': 'session-token',
      'backendApiBaseUrl': 'https://api.example.test/',
      'profile': 'activeTrip',
    });
  });

  test('profile update carries no credentials', () {
    expect(
      NativeDriverTrackingProfileUpdate(
        TrackingProfile.available,
      ).toMethodArguments(),
      {'profile': 'available'},
    );
  });
}
