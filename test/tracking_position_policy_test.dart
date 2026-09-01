import 'package:fleet_control/features/tracking/domain/tracking_position_policy.dart';
import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  const policy = TrackingPositionPolicy();
  final now = DateTime.utc(2030, 1, 1, 12);

  group('TrackingProfile configuration', () {
    test('idle disables tracking', () {
      expect(trackingConfigurationFor(TrackingProfile.idle).isEnabled, isFalse);
    });

    test('available uses balanced foreground settings', () {
      final configuration = trackingConfigurationFor(TrackingProfile.available);

      expect(configuration.accuracy, LocationAccuracy.medium);
      expect(configuration.distanceFilterMeters, 75);
      expect(configuration.androidInterval, const Duration(seconds: 45));
      expect(configuration.forceGpsInterval, const Duration(minutes: 2));
      expect(configuration.maximumAccuracyMeters, 100);
    });

    test('active trip uses high accuracy foreground settings', () {
      final configuration = trackingConfigurationFor(
        TrackingProfile.activeTrip,
      );

      expect(configuration.accuracy, LocationAccuracy.high);
      expect(configuration.distanceFilterMeters, 20);
      expect(configuration.androidInterval, const Duration(seconds: 12));
      expect(configuration.forceGpsInterval, const Duration(seconds: 45));
      expect(configuration.maximumAccuracyMeters, 50);
    });
  });

  group('TrackingPositionPolicy validation', () {
    test('accepts a valid available reading', () {
      expect(
        policy.validate(
          _position(timestamp: now.subtract(const Duration(seconds: 30))),
          profile: TrackingProfile.available,
          now: now,
        ),
        isNull,
      );
    });

    test('rejects invalid coordinates', () {
      expect(
        policy.validate(
          _position(latitude: 91, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.invalidCoordinates,
      );
      expect(
        policy.validate(
          _position(longitude: double.infinity, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.invalidCoordinates,
      );
      expect(
        policy.validate(
          _position(latitude: double.nan, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.invalidCoordinates,
      );
    });

    test('rejects stale and future readings', () {
      expect(
        policy.validate(
          _position(timestamp: now.subtract(const Duration(seconds: 121))),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.staleTimestamp,
      );
      expect(
        policy.validate(
          _position(timestamp: now.add(const Duration(seconds: 11))),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.futureTimestamp,
      );
    });

    test('rejects stale or inaccurate forced GPS readings too', () {
      expect(
        policy.validate(
          _position(timestamp: now.subtract(const Duration(seconds: 121))),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.staleTimestamp,
      );
      expect(
        policy.validate(
          _position(accuracy: 101, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.invalidAccuracy,
      );
    });

    test('enforces accuracy per profile', () {
      expect(
        policy.validate(
          _position(accuracy: 101, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
        ),
        PositionRejectionReason.invalidAccuracy,
      );
      expect(
        policy.validate(
          _position(accuracy: 51, timestamp: now),
          profile: TrackingProfile.activeTrip,
          now: now,
        ),
        PositionRejectionReason.invalidAccuracy,
      );
    });
  });

  group('TrackingPositionPolicy send rules', () {
    final last = _position(timestamp: DateTime.utc(2030, 1, 1, 11, 59));

    test('rate limits a new reading that arrives too soon', () {
      expect(
        policy.shouldSend(
          _position(latitude: -25.285, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 10)),
        ),
        PositionRejectionReason.rateLimited,
      );
    });

    test('rejects insignificant movement before the maximum interval', () {
      expect(
        policy.shouldSend(
          _position(latitude: -25.28665, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 60)),
        ),
        PositionRejectionReason.insufficientMovement,
      );
    });

    test('rejects an identical reading with the same timestamp', () {
      expect(
        policy.shouldSend(
          last,
          profile: TrackingProfile.available,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 60)),
        ),
        PositionRejectionReason.duplicate,
      );
    });

    test('allows enough movement and the maximum-interval fallback', () {
      expect(
        policy.shouldSend(
          _position(latitude: -25.2860, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 60)),
        ),
        isNull,
      );
      expect(
        policy.shouldSend(
          _position(latitude: -25.28665, timestamp: now),
          profile: TrackingProfile.available,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(minutes: 2)),
        ),
        isNull,
      );
    });

    test('rejects an evident GPS jump but accepts ordinary movement', () {
      expect(
        policy.shouldSend(
          _position(latitude: -25.280, timestamp: now),
          profile: TrackingProfile.activeTrip,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 60)),
        ),
        isNull,
      );
      expect(
        policy.shouldSend(
          _position(latitude: -24.0, timestamp: now),
          profile: TrackingProfile.activeTrip,
          now: now,
          lastSentPosition: last,
          lastSentAt: now.subtract(const Duration(seconds: 60)),
        ),
        PositionRejectionReason.implausibleJump,
      );
    });
  });

  test('backpressure keeps only the newest pending reading', () {
    final buffer = LatestPositionBuffer();
    final first = _position(
      timestamp: now.subtract(const Duration(seconds: 3)),
    );
    final second = _position(
      timestamp: now.subtract(const Duration(seconds: 2)),
    );
    final third = _position(
      timestamp: now.subtract(const Duration(seconds: 1)),
    );

    expect(buffer.startOrBuffer(first, force: false), isTrue);
    expect(buffer.isSending, isTrue);
    expect(buffer.startOrBuffer(second, force: false), isFalse);
    expect(buffer.startOrBuffer(third, force: true), isFalse);

    final pending = buffer.finish();
    expect(buffer.isSending, isFalse);
    expect(pending?.position, same(third));
    expect(pending?.force, isTrue);
    expect(buffer.pendingPosition, isNull);
  });
}

Position _position({
  double latitude = -25.2867,
  double longitude = -57.647,
  double accuracy = 10,
  required DateTime timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
