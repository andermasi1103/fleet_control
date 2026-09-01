import 'dart:async';

import '../domain/driver_presence_schedule.dart';
import '../domain/tracking_profile.dart';

abstract interface class PresenceTimer {
  void cancel();
}

typedef PresenceTimerFactory =
    PresenceTimer Function(Duration interval, void Function() callback);
typedef PresenceHeartbeatSender = Future<void> Function(String sessionToken);

class DriverPresenceController {
  DriverPresenceController({
    required this.sendHeartbeat,
    PresenceTimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? _startPeriodicTimer;

  final PresenceHeartbeatSender sendHeartbeat;
  final PresenceTimerFactory _timerFactory;

  PresenceTimer? _timer;
  String? _sessionToken;
  Duration? _interval;
  int _generation = 0;
  int? _sendingGeneration;

  bool get isActive => _timer != null;

  void configure({
    required String? sessionToken,
    required TrackingProfile profile,
    required bool isInForeground,
  }) {
    final interval = presenceHeartbeatIntervalFor(profile);
    final shouldRun =
        sessionToken != null &&
        sessionToken.isNotEmpty &&
        isInForeground &&
        interval != null;
    if (!shouldRun) {
      stop();
      return;
    }

    if (_timer != null &&
        _sessionToken == sessionToken &&
        _interval == interval) {
      return;
    }

    stop();
    _sessionToken = sessionToken;
    _interval = interval;
    final generation = _generation;
    _timer = _timerFactory(
      interval,
      () => unawaited(_send(generation, sessionToken)),
    );
    unawaited(_send(generation, sessionToken));
  }

  void stop() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _sessionToken = null;
    _interval = null;
    _sendingGeneration = null;
  }

  void dispose() => stop();

  Future<void> _send(int generation, String sessionToken) async {
    if (generation != _generation ||
        sessionToken != _sessionToken ||
        _sendingGeneration != null) {
      return;
    }

    _sendingGeneration = generation;
    try {
      await sendHeartbeat(sessionToken);
    } catch (_) {
      // A future tick retries; presence failures never affect GPS tracking.
    } finally {
      if (_sendingGeneration == generation) {
        _sendingGeneration = null;
      }
    }
  }

  static PresenceTimer _startPeriodicTimer(
    Duration interval,
    void Function() callback,
  ) {
    return _TimerAdapter(Timer.periodic(interval, (_) => callback()));
  }
}

class _TimerAdapter implements PresenceTimer {
  const _TimerAdapter(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
