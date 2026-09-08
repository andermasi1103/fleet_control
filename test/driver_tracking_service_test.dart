import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:fleet_control/features/tracking/services/driver_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android fallback keeps the available tracking profile', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings = DriverTrackingService().locationSettingsFor(
      TrackingProfile.available,
    ) as AndroidSettings;

    expect(settings.accuracy, LocationAccuracy.medium);
    expect(settings.distanceFilter, 75);
    expect(settings.intervalDuration, const Duration(seconds: 45));
    // Android background ownership belongs exclusively to DriverTrackingService
    // (Kotlin), never to Geolocator's Activity-bound foreground wrapper.
    expect(settings.foregroundNotificationConfig, isNull);
  });

  test('Android active trips keep high-accuracy tracking settings', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final settings = DriverTrackingService().locationSettingsFor(
      TrackingProfile.activeTrip,
    ) as AndroidSettings;

    expect(settings.accuracy, LocationAccuracy.high);
    expect(settings.distanceFilter, 20);
    expect(settings.intervalDuration, const Duration(seconds: 12));
    expect(settings.foregroundNotificationConfig, isNull);
  });
}
