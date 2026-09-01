import 'dart:async';

import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:fleet_control/features/tracking/services/driver_force_gps_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the configured available and active-trip intervals', () {
    final timers = <_FakeTimer>[];
    final scheduler = DriverForceGpsScheduler(
      requestGps: (_) async {},
      timerFactory: (interval, callback) {
        final timer = _FakeTimer(interval, callback);
        timers.add(timer);
        return timer;
      },
    );

    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    expect(timers.single.interval, const Duration(minutes: 2));

    scheduler.configure(
      profile: TrackingProfile.activeTrip,
      isInForeground: true,
    );
    expect(timers.first.isCancelled, isTrue);
    expect(timers.last.interval, const Duration(seconds: 45));
  });

  test('does not run for idle or outside the foreground', () {
    final timers = <_FakeTimer>[];
    final scheduler = _scheduler(timers, (_) async {});

    scheduler.configure(profile: TrackingProfile.idle, isInForeground: true);
    expect(timers, isEmpty);
    expect(scheduler.isActive, isFalse);

    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: false,
    );
    expect(timers, isEmpty);
  });

  test('a movement send postpones the next forced sample', () {
    final timers = <_FakeTimer>[];
    final scheduler = _scheduler(timers, (_) async {});
    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: true,
    );

    scheduler.noteLocationSent();

    expect(timers, hasLength(2));
    expect(timers.first.isCancelled, isTrue);
    expect(timers.last.interval, const Duration(minutes: 2));
  });

  test('does not overlap forced GPS requests and retries after failure', () async {
    final timers = <_FakeTimer>[];
    final request = Completer<void>();
    var attempts = 0;
    final scheduler = _scheduler(timers, (_) async {
      attempts += 1;
      await request.future;
    });
    scheduler.configure(
      profile: TrackingProfile.activeTrip,
      isInForeground: true,
    );

    timers.single.callback();
    await Future<void>.value();
    timers.last.callback();
    await Future<void>.value();
    expect(attempts, 1);

    request.complete();
    await Future<void>.value();

    final failedScheduler = _scheduler(timers, (_) async {
      throw StateError('GPS unavailable');
    });
    failedScheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    timers.last.callback();
    await Future<void>.value();
    expect(timers.last.interval, const Duration(minutes: 2));
  });

  test('pause and dispose cancel the pending timer', () {
    final timers = <_FakeTimer>[];
    final scheduler = _scheduler(timers, (_) async {});
    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: false,
    );
    expect(timers.last.isCancelled, isTrue);

    scheduler.configure(
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    scheduler.dispose();
    expect(timers.last.isCancelled, isTrue);
  });
}

DriverForceGpsScheduler _scheduler(
  List<_FakeTimer> timers,
  ForcedGpsRequest requestGps,
) {
  return DriverForceGpsScheduler(
    requestGps: requestGps,
    timerFactory: (interval, callback) {
      final timer = _FakeTimer(interval, callback);
      timers.add(timer);
      return timer;
    },
  );
}

class _FakeTimer implements ForceGpsTimer {
  _FakeTimer(this.interval, this.callback);

  final Duration interval;
  final void Function() callback;
  bool isCancelled = false;

  @override
  void cancel() {
    isCancelled = true;
  }
}
