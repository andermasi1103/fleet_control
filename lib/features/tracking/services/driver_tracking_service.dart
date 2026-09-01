import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/tracking_profile.dart';

enum DriverLocationAccess {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DriverTrackingService {
  Future<DriverLocationAccess> requestLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return DriverLocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Android presents the background-location grant separately after the
    // foreground grant. It is required for the driver's location foreground
    // service to keep receiving updates after the UI is backgrounded.
    if (defaultTargetPlatform == TargetPlatform.android &&
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return DriverLocationAccess.permissionDeniedForever;
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return DriverLocationAccess.permissionDenied;
    }

    return DriverLocationAccess.granted;
  }

  /// Requests a fresh GPS reading for startup and periodic forced samples.
  Future<Position> getCurrentPosition(TrackingProfile profile) {
    return Geolocator.getCurrentPosition(
      locationSettings: locationSettingsFor(profile),
    );
  }

  Stream<Position> getPositionStream(TrackingProfile profile) {
    return Geolocator.getPositionStream(
      locationSettings: locationSettingsFor(profile),
    );
  }

  LocationSettings locationSettingsFor(TrackingProfile profile) {
    final configuration = trackingConfigurationFor(profile);
    if (!configuration.isEnabled) {
      throw ArgumentError.value(profile, 'profile', 'Idle does not track.');
    }

    if (kIsWeb) {
      return WebSettings(
        accuracy: configuration.accuracy!,
        distanceFilter: configuration.distanceFilterMeters!,
        maximumAge: configuration.webMaximumAgeDuration,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: configuration.accuracy!,
        distanceFilter: configuration.distanceFilterMeters!,
        intervalDuration: configuration.androidIntervalDuration,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MasiTrack',
          notificationText: 'Ubicación activa para seguimiento de flota',
          notificationChannelName: 'MasiTrack — Seguimiento de flota',
          setOngoing: true,
          enableWakeLock: false,
          enableWifiLock: false,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: configuration.accuracy!,
        distanceFilter: configuration.distanceFilterMeters!,
        pauseLocationUpdatesAutomatically: profile == TrackingProfile.available,
        showBackgroundLocationIndicator: false,
        allowBackgroundLocationUpdates: false,
      );
    }

    return LocationSettings(
      accuracy: configuration.accuracy!,
      distanceFilter: configuration.distanceFilterMeters!,
    );
  }
}
