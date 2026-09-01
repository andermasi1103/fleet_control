import 'dart:async';

import '../domain/tracking_profile.dart';

abstract interface class ForceGpsTimer {
  void cancel();
}

typedef ForceGpsTimerFactory =
    ForceGpsTimer Function(Duration interval, void Function() callback);
typedef ForcedGpsRequest = Future<void> Function(DateTime dueAt);

/// Schedules foreground GPS samples independently from movement updates.
class DriverForceGpsScheduler {
  DriverForceGpsScheduler({
    required this.requestGps,
    ForceGpsTimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? _startTimer;

  final ForcedGpsRequest requestGps;
  final ForceGpsTimerFactory _timerFactory;

  ForceGpsTimer? _timer;
  TrackingProfile _profile = TrackingProfile.idle;
  Duration? _interval;
  bool _isInForeground = false;
  bool _isRequesting = false;
  int _generation = 0;
  int _requestGeneration = 0;

  bool get isActive => _timer != null;

  void configure({
    required TrackingProfile profile,
    required bool isInForeground,
  }) {
    final configuration = trackingConfigurationFor(profile);
    final shouldRun = configuration.isEnabled && isInForeground;
    if (!shouldRun) {
      stop();
      return;
    }

    final interval = configuration.forceGpsIntervalDuration;
    if (_timer != null &&
        _profile == profile &&
        _interval == interval &&
        _isInForeground == isInForeground) {
      return;
    }

    _profile = profile;
    _interval = interval;
    _isInForeground = isInForeground;
    _scheduleNext();
  }

  /// Delays the next forced sample from a successfully sent GPS reading.
  void noteLocationSent() {
    if (_timer == null || !_isInForeground) return;
    _scheduleNext();
  }

  void stop() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _profile = TrackingProfile.idle;
    _interval = null;
    _isInForeground = false;
    ++_requestGeneration;
    _isRequesting = false;
  }

  void dispose() => stop();

  void _scheduleNext() {
    final interval = _interval;
    if (interval == null || !_isInForeground) return;

    ++_generation;
    _timer?.cancel();
    final generation = _generation;
    final dueAt = DateTime.now().add(interval);
    _timer = _timerFactory(
      interval,
      () => unawaited(_requestAt(generation, dueAt)),
    );
  }

  Future<void> _requestAt(int generation, DateTime dueAt) async {
    if (generation != _generation || !_isInForeground) return;
    if (_isRequesting) {
      _scheduleNext();
      return;
    }

    _timer = null;
    _isRequesting = true;
    final requestGeneration = ++_requestGeneration;
    _scheduleNext();
    try {
      await requestGps(dueAt);
    } catch (_) {
      // A later scheduled sample retries; GPS failures never create data.
    } finally {
      if (requestGeneration == _requestGeneration) {
        _isRequesting = false;
      }
    }
  }

  static ForceGpsTimer _startTimer(
    Duration interval,
    void Function() callback,
  ) {
    return _TimerAdapter(Timer(interval, callback));
  }
}

class _TimerAdapter implements ForceGpsTimer {
  const _TimerAdapter(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
