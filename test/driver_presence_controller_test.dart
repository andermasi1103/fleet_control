import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:fleet_control/features/tracking/services/driver_presence_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presence follows profile frequency and foreground lifecycle', () async {
    final timers = <_FakeTimer>[];
    var heartbeats = 0;
    final controller = DriverPresenceController(
      sendHeartbeat: (_) async => heartbeats += 1,
      timerFactory: (interval, callback) {
        final timer = _FakeTimer(interval, callback);
        timers.add(timer);
        return timer;
      },
    );

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    await Future<void>.value();
    expect(timers.single.interval, const Duration(seconds: 60));
    expect(heartbeats, 1);

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    expect(timers, hasLength(1));

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.activeTrip,
      isInForeground: true,
    );
    await Future<void>.value();
    expect(timers.first.isCancelled, isTrue);
    expect(timers.last.interval, const Duration(seconds: 30));
    expect(heartbeats, 2);

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.activeTrip,
      isInForeground: false,
    );
    expect(timers.last.isCancelled, isTrue);
    expect(controller.isActive, isFalse);

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.activeTrip,
      isInForeground: true,
    );
    await Future<void>.value();
    expect(timers.last.interval, const Duration(seconds: 30));
    expect(controller.isActive, isTrue);

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    await Future<void>.value();
    expect(timers[timers.length - 2].isCancelled, isTrue);
    expect(timers.last.interval, const Duration(seconds: 60));

    controller.configure(
      sessionToken: 'token',
      profile: TrackingProfile.idle,
      isInForeground: true,
    );
    expect(timers.last.isCancelled, isTrue);
    expect(controller.isActive, isFalse);

    controller.configure(
      sessionToken: null,
      profile: TrackingProfile.available,
      isInForeground: true,
    );
    expect(controller.isActive, isFalse);
  });

  test(
    'a failed heartbeat does not block the next scheduled heartbeat',
    () async {
      final timers = <_FakeTimer>[];
      var attempts = 0;
      final controller = DriverPresenceController(
        sendHeartbeat: (_) async {
          attempts += 1;
          if (attempts == 1) throw StateError('network unavailable');
        },
        timerFactory: (interval, callback) {
          final timer = _FakeTimer(interval, callback);
          timers.add(timer);
          return timer;
        },
      );

      controller.configure(
        sessionToken: 'token',
        profile: TrackingProfile.available,
        isInForeground: true,
      );
      await Future<void>.value();
      timers.single.callback();
      await Future<void>.value();

      expect(attempts, 2);
    },
  );
}

class _FakeTimer implements PresenceTimer {
  _FakeTimer(this.interval, this.callback);

  final Duration interval;
  final void Function() callback;
  bool isCancelled = false;

  @override
  void cancel() {
    isCancelled = true;
  }
}
