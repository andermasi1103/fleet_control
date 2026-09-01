import 'package:geolocator/geolocator.dart';

import 'tracking_profile.dart';

enum PositionRejectionReason {
  trackingDisabled,
  invalidCoordinates,
  invalidAccuracy,
  staleTimestamp,
  futureTimestamp,
  duplicate,
  rateLimited,
  insufficientMovement,
  implausibleJump,
}

/// Pure decision rules for locations received from Geolocator.
class TrackingPositionPolicy {
  const TrackingPositionPolicy({
    this.maximumPositionAge = const Duration(seconds: 120),
    this.maximumFutureSkew = const Duration(seconds: 10),
    this.maximumPlausibleSpeedMetersPerSecond = 70,
  });

  final Duration maximumPositionAge;
  final Duration maximumFutureSkew;

  /// 70 m/s is 252 km/h: intentionally conservative for MasiTrack.
  final double maximumPlausibleSpeedMetersPerSecond;

  PositionRejectionReason? validate(
    Position position, {
    required TrackingProfile profile,
    required DateTime now,
  }) {
    final configuration = trackingConfigurationFor(profile);
    if (!configuration.isEnabled) return PositionRejectionReason.trackingDisabled;

    if (!_hasValidCoordinates(position)) {
      return PositionRejectionReason.invalidCoordinates;
    }

    final accuracy = position.accuracy;
    final maximumAccuracy = configuration.maximumAccuracyMeters;
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        maximumAccuracy == null ||
        accuracy > maximumAccuracy) {
      return PositionRejectionReason.invalidAccuracy;
    }

    final capturedAt = position.timestamp.toUtc();
    final referenceNow = now.toUtc();
    if (capturedAt.isAfter(referenceNow.add(maximumFutureSkew))) {
      return PositionRejectionReason.futureTimestamp;
    }
    if (referenceNow.difference(capturedAt) > maximumPositionAge) {
      return PositionRejectionReason.staleTimestamp;
    }

    return null;
  }

  PositionRejectionReason? shouldSend(
    Position position, {
    required TrackingProfile profile,
    required DateTime now,
    Position? lastSentPosition,
    DateTime? lastSentAt,
    bool force = false,
  }) {
    final validation = validate(position, profile: profile, now: now);
    if (validation != null) return validation;
    if (force || lastSentPosition == null || lastSentAt == null) return null;

    if (_isDuplicate(position, lastSentPosition)) {
      return PositionRejectionReason.duplicate;
    }
    if (_isImplausibleJump(position, lastSentPosition)) {
      return PositionRejectionReason.implausibleJump;
    }

    final configuration = trackingConfigurationFor(profile);
    final elapsed = now.toUtc().difference(lastSentAt.toUtc());
    if (elapsed < configuration.minimumSendInterval!) {
      return PositionRejectionReason.rateLimited;
    }

    final distance = Geolocator.distanceBetween(
      lastSentPosition.latitude,
      lastSentPosition.longitude,
      position.latitude,
      position.longitude,
    );
    if (distance >= configuration.minimumSendDistanceMeters!) return null;
    if (elapsed >= configuration.maximumSendInterval!) return null;

    return PositionRejectionReason.insufficientMovement;
  }

  bool _hasValidCoordinates(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  bool _isDuplicate(Position position, Position lastSentPosition) {
    return position.timestamp.toUtc() == lastSentPosition.timestamp.toUtc() &&
        position.latitude == lastSentPosition.latitude &&
        position.longitude == lastSentPosition.longitude;
  }

  bool _isImplausibleJump(Position position, Position lastSentPosition) {
    final elapsed = position.timestamp
        .toUtc()
        .difference(lastSentPosition.timestamp.toUtc());
    if (elapsed <= Duration.zero) return false;

    final distance = Geolocator.distanceBetween(
      lastSentPosition.latitude,
      lastSentPosition.longitude,
      position.latitude,
      position.longitude,
    );
    return distance / elapsed.inMilliseconds * 1000 >
        maximumPlausibleSpeedMetersPerSecond;
  }
}

/// Holds at most one newer reading while an HTTP request is in flight.
class LatestPositionBuffer {
  bool _sending = false;
  Position? _pendingPosition;
  bool _pendingForce = false;

  bool get isSending => _sending;
  Position? get pendingPosition => _pendingPosition;

  bool startOrBuffer(Position position, {required bool force}) {
    if (_sending) {
      _pendingPosition = position;
      _pendingForce = _pendingForce || force;
      return false;
    }
    _sending = true;
    return true;
  }

  ({Position position, bool force})? finish() {
    _sending = false;
    final position = _pendingPosition;
    final force = _pendingForce;
    _pendingPosition = null;
    _pendingForce = false;
    if (position == null) return null;
    return (position: position, force: force);
  }

  void reset() {
    _sending = false;
    _pendingPosition = null;
    _pendingForce = false;
  }
}
