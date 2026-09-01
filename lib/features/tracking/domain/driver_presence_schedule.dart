import 'tracking_profile.dart';

Duration? presenceHeartbeatIntervalFor(TrackingProfile profile) {
  final configuration = trackingConfigurationFor(profile);
  if (!configuration.isEnabled) return null;
  return configuration.presenceHeartbeatIntervalDuration;
}
