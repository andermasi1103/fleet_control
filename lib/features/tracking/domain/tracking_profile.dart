import 'package:geolocator/geolocator.dart';

/// Defines the expected operational intensity for foreground tracking.
enum TrackingProfile { idle, available, activeTrip }

/// Keeps every tunable tracking value in one place.
class TrackingProfileConfiguration {
  const TrackingProfileConfiguration({
    required this.isEnabled,
    this.accuracy,
    this.distanceFilterMeters,
    this.androidInterval,
    this.forceGpsInterval,
    this.presenceHeartbeatInterval,
    this.webMaximumAge,
    this.maximumAccuracyMeters,
    this.minimumSendInterval,
    this.maximumSendInterval,
    this.minimumSendDistanceMeters,
  });

  final bool isEnabled;
  final LocationAccuracy? accuracy;
  final int? distanceFilterMeters;
  final Duration? androidInterval;
  final Duration? forceGpsInterval;
  final Duration? presenceHeartbeatInterval;
  final Duration? webMaximumAge;
  final double? maximumAccuracyMeters;
  final Duration? minimumSendInterval;
  final Duration? maximumSendInterval;
  final double? minimumSendDistanceMeters;

  Duration get androidIntervalDuration {
    final interval = androidInterval;
    if (!isEnabled || interval == null) {
      throw StateError(
        'An enabled tracking profile must define an Android interval.',
      );
    }
    return interval;
  }

  Duration get webMaximumAgeDuration {
    final maximumAge = webMaximumAge;
    if (!isEnabled || maximumAge == null) {
      throw StateError(
        'An enabled tracking profile must define a web maximum age.',
      );
    }
    return maximumAge;
  }

  Duration get presenceHeartbeatIntervalDuration {
    final interval = presenceHeartbeatInterval;
    if (!isEnabled || interval == null) {
      throw StateError(
        'An enabled tracking profile must define a presence heartbeat interval.',
      );
    }
    return interval;
  }

  Duration get forceGpsIntervalDuration {
    final interval = forceGpsInterval;
    if (!isEnabled || interval == null) {
      throw StateError(
        'An enabled tracking profile must define a forced GPS interval.',
      );
    }
    return interval;
  }
}

const _idleConfiguration = TrackingProfileConfiguration(isEnabled: false);

const _availableConfiguration = TrackingProfileConfiguration(
  isEnabled: true,
  accuracy: LocationAccuracy.medium,
  distanceFilterMeters: 75,
  androidInterval: Duration(seconds: 45),
  forceGpsInterval: Duration(minutes: 2),
  presenceHeartbeatInterval: Duration(seconds: 60),
  webMaximumAge: Duration(minutes: 5),
  maximumAccuracyMeters: 100,
  minimumSendInterval: Duration(seconds: 45),
  maximumSendInterval: Duration(minutes: 2),
  minimumSendDistanceMeters: 25,
);

const _activeTripConfiguration = TrackingProfileConfiguration(
  isEnabled: true,
  accuracy: LocationAccuracy.high,
  distanceFilterMeters: 20,
  androidInterval: Duration(seconds: 12),
  forceGpsInterval: Duration(seconds: 45),
  presenceHeartbeatInterval: Duration(seconds: 30),
  webMaximumAge: Duration(minutes: 2),
  maximumAccuracyMeters: 50,
  minimumSendInterval: Duration(seconds: 12),
  maximumSendInterval: Duration(seconds: 45),
  minimumSendDistanceMeters: 10,
);

TrackingProfileConfiguration trackingConfigurationFor(TrackingProfile profile) {
  return switch (profile) {
    TrackingProfile.idle => _idleConfiguration,
    TrackingProfile.available => _availableConfiguration,
    TrackingProfile.activeTrip => _activeTripConfiguration,
  };
}
