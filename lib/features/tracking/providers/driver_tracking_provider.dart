import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/domain/entities/auth_session.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/driver_location_data_source.dart';
import '../domain/tracking_position_policy.dart';
import '../domain/tracking_profile.dart';
import '../services/driver_force_gps_scheduler.dart';
import '../services/driver_tracking_service.dart';

enum DriverTrackingStatus {
  idle,
  starting,
  active,
  sending,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

class DriverTrackingState {
  const DriverTrackingState({
    this.status = DriverTrackingStatus.idle,
    this.profile = TrackingProfile.idle,
    this.lastSentAt,
    this.message,
  });

  final DriverTrackingStatus status;
  final TrackingProfile profile;
  final DateTime? lastSentAt;
  final String? message;
}

final driverLocationDataSourceProvider = Provider<DriverLocationDataSource>((
  ref,
) {
  return DriverLocationDataSource(ref.watch(backendApiClientProvider));
});

final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  return DriverTrackingService();
});

final driverTrackingProvider =
    NotifierProvider<DriverTrackingNotifier, DriverTrackingState>(
      DriverTrackingNotifier.new,
    );

class DriverTrackingNotifier extends Notifier<DriverTrackingState> {
  static const _positionPolicy = TrackingPositionPolicy();

  StreamSubscription<Position>? _positionSubscription;
  late final DriverForceGpsScheduler _forceGpsScheduler;
  final _backpressure = LatestPositionBuffer();
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  String? _trackedUserId;
  String? _sessionToken;
  TrackingProfile _profile = TrackingProfile.idle;
  bool _isInForeground = true;
  bool _isStarting = false;
  int _generation = 0;

  @override
  DriverTrackingState build() {
    _forceGpsScheduler = DriverForceGpsScheduler(
      requestGps: _requestForcedPosition,
    );
    ref.listen(sessionProvider, (_, next) {
      if (ref.read(postLoginBootstrapProvider)) {
        unawaited(_synchronizeSession(next.session));
      }
    });
    ref.listen(postLoginBootstrapProvider, (_, isReady) {
      if (isReady) {
        unawaited(_synchronizeSession(ref.read(sessionProvider).session));
      } else {
        unawaited(_stop(setIdleState: true));
      }
    });
    if (ref.read(postLoginBootstrapProvider)) {
      Future.microtask(
        () => _synchronizeSession(ref.read(sessionProvider).session),
      );
    }
    ref.onDispose(_dispose);
    return DriverTrackingState(profile: _profile);
  }

  /// The future operational-state source will call this method.
  Future<void> setProfile(TrackingProfile profile) async {
    if (_profile == profile) return;

    _profile = profile;
    await _stop(setIdleState: true);
    if (_profile.isEnabled &&
        _isInForeground &&
        ref.read(postLoginBootstrapProvider)) {
      await _synchronizeSession(ref.read(sessionProvider).session);
    }
  }

  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {
    if (lifecycleState == AppLifecycleState.resumed) {
      _isInForeground = true;
      if (ref.read(postLoginBootstrapProvider)) {
        await _synchronizeSession(ref.read(sessionProvider).session);
      }
      return;
    }

    // On Android, Geolocator owns a location foreground service with a
    // persistent notification. The Flutter UI lifecycle must not stop that
    // service while an eligible driver's tracking profile remains active.
    if (defaultTargetPlatform == TargetPlatform.android &&
        _profile.isEnabled &&
        _sessionToken != null) {
      return;
    }

    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _isInForeground = false;
      await _stop(setIdleState: true);
    }
  }

  Future<void> _synchronizeSession(AuthSession? session) async {
    if (!_profile.isEnabled ||
        !_isInForeground ||
        !_isEligibleDriver(session)) {
      await _stop(setIdleState: true);
      return;
    }

    if (_isStarting ||
        (_trackedUserId == session!.user.id &&
            _sessionToken == session.sessionToken &&
            _positionSubscription != null)) {
      return;
    }

    await _start(session);
  }

  bool _isEligibleDriver(AuthSession? session) {
    return session != null &&
        !session.isExpired &&
        session.sessionToken.isNotEmpty &&
        session.user.role == 'chofer';
  }

  Future<void> _start(AuthSession session) async {
    await _stop(setIdleState: false);
    _isStarting = true;
    final generation = ++_generation;
    _trackedUserId = session.user.id;
    _sessionToken = session.sessionToken;
    state = DriverTrackingState(
      status: DriverTrackingStatus.starting,
      profile: _profile,
    );

    try {
      final access = await ref
          .read(driverTrackingServiceProvider)
          .requestLocationAccess();
      if (!_isCurrentSession(generation, session)) return;

      switch (access) {
        case DriverLocationAccess.serviceDisabled:
          _setAccessState(
            DriverTrackingStatus.serviceDisabled,
            'Activa la ubicación para aparecer disponible en MasiTrack. Aparecerás como sin conexión para el supervisor.',
          );
          return;
        case DriverLocationAccess.permissionDenied:
          _setAccessState(
            DriverTrackingStatus.permissionDenied,
            'MasiTrack necesita permiso de ubicación para informar tu disponibilidad.',
          );
          return;
        case DriverLocationAccess.permissionDeniedForever:
          _setAccessState(
            DriverTrackingStatus.permissionDeniedForever,
            'El permiso de ubicación está bloqueado. Habilítalo desde la configuración del dispositivo.',
          );
          return;
        case DriverLocationAccess.granted:
          break;
      }

      final initialPosition = await ref
          .read(driverTrackingServiceProvider)
          .getCurrentPosition(_profile);
      if (!_isCurrentSession(generation, session)) return;

      await _sendOrBuffer(initialPosition, force: true);
      if (!_isCurrentSession(generation, session)) return;

      _positionSubscription = ref
          .read(driverTrackingServiceProvider)
          .getPositionStream(_profile)
          .listen(
            (position) => unawaited(_sendOrBuffer(position)),
            onError: (_) => _setTemporaryError(
              'Ubicación desactivada. Aparecerás como sin conexión para el supervisor.',
            ),
          );
      _forceGpsScheduler.configure(
        profile: _profile,
        isInForeground: _isInForeground,
      );
    } on LocationServiceDisabledException {
      _setAccessState(
        DriverTrackingStatus.serviceDisabled,
        'Activa la ubicación para aparecer disponible en MasiTrack. Aparecerás como sin conexión para el supervisor.',
      );
    } on PermissionDeniedException {
      _setAccessState(
        DriverTrackingStatus.permissionDenied,
        'MasiTrack necesita permiso de ubicación para informar tu disponibilidad.',
      );
    } catch (_) {
      _setTemporaryError(
        'Ubicación desactivada. Aparecerás como sin conexión para el supervisor.',
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _requestForcedPosition(DateTime dueAt) async {
    final generation = _generation;
    final profile = _profile;
    if (!profile.isEnabled || !_isInForeground || _sessionToken == null) return;

    try {
      final position = await ref
          .read(driverTrackingServiceProvider)
          .getCurrentPosition(profile);
      if (generation != _generation ||
          !_isInForeground ||
          _sessionToken == null ||
          !_lastSentBefore(dueAt)) {
        return;
      }
      await _sendOrBuffer(position, force: true);
    } on LocationServiceDisabledException {
      _setTemporaryError('Ubicación desactivada.');
    } on PermissionDeniedException {
      _setTemporaryError('MasiTrack necesita permiso de ubicación.');
    } catch (_) {
      _setTemporaryError('No fue posible obtener una ubicación GPS actual.');
    }
  }

  bool _lastSentBefore(DateTime dueAt) {
    final lastSentAt = _lastSentAt;
    return lastSentAt == null || lastSentAt.isBefore(dueAt);
  }

  Future<void> _sendOrBuffer(Position position, {bool force = false}) async {
    final validation = _positionPolicy.validate(
      position,
      profile: _profile,
      now: DateTime.now(),
    );
    if (validation != null) {
      _logRejectedPosition(validation);
      return;
    }
    if (!_backpressure.startOrBuffer(position, force: force)) return;
    final generation = _generation;

    try {
      await _sendPosition(position, force: force, generation: generation);
    } finally {
      if (generation == _generation) {
        final pending = _backpressure.finish();
        if (pending != null && _sessionToken != null && _profile.isEnabled) {
          await _sendOrBuffer(pending.position, force: pending.force);
        }
      }
    }
  }

  Future<void> _sendPosition(
    Position position, {
    required bool force,
    required int generation,
  }) async {
    final rejection = _positionPolicy.shouldSend(
      position,
      profile: _profile,
      now: DateTime.now(),
      lastSentPosition: _lastSentPosition,
      lastSentAt: _lastSentAt,
      force: force,
    );
    if (_sessionToken == null || rejection != null) {
      _logRejectedPosition(rejection);
      return;
    }

    state = DriverTrackingState(
      status: DriverTrackingStatus.sending,
      profile: _profile,
      lastSentAt: _lastSentAt,
    );

    final sessionToken = _sessionToken;
    try {
      await ref
          .read(driverLocationDataSourceProvider)
          .updateLocation(sessionToken: sessionToken!, position: position);
      if (_sessionToken != sessionToken || generation != _generation) return;

      _lastSentPosition = position;
      _lastSentAt = DateTime.now();
      _forceGpsScheduler.noteLocationSent();
      state = DriverTrackingState(
        status: DriverTrackingStatus.active,
        profile: _profile,
        lastSentAt: _lastSentAt,
      );
      if (kDebugMode) debugPrint('driver-location sent');
    } on Failure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _stop(setIdleState: false);
        state = DriverTrackingState(
          status: DriverTrackingStatus.error,
          profile: _profile,
          lastSentAt: _lastSentAt,
          message: error.message,
        );
        return;
      }

      _setTemporaryError('Error temporal al actualizar la ubicación.');
    } catch (_) {
      _setTemporaryError('Error temporal al actualizar la ubicación.');
    }
  }

  bool _isCurrentSession(int generation, AuthSession session) {
    return _profile.isEnabled &&
        _isInForeground &&
        generation == _generation &&
        _trackedUserId == session.user.id &&
        _sessionToken == session.sessionToken;
  }

  void _logRejectedPosition(PositionRejectionReason? reason) {
    if (kDebugMode && reason != null) {
      debugPrint('driver-location ignored: ${reason.name}');
    }
  }

  void _setAccessState(DriverTrackingStatus status, String message) {
    state = DriverTrackingState(
      status: status,
      profile: _profile,
      lastSentAt: _lastSentAt,
      message: message,
    );
  }

  void _setTemporaryError(String message) {
    state = DriverTrackingState(
      status: DriverTrackingStatus.error,
      profile: _profile,
      lastSentAt: _lastSentAt,
      message: message,
    );
  }

  Future<void> _stop({required bool setIdleState}) async {
    ++_generation;
    _isStarting = false;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    _forceGpsScheduler.stop();
    _backpressure.reset();
    _lastSentPosition = null;
    _lastSentAt = null;
    _trackedUserId = null;
    _sessionToken = null;
    if (setIdleState) state = DriverTrackingState(profile: _profile);
  }

  void _dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _forceGpsScheduler.dispose();
    _backpressure.reset();
  }
}

extension on TrackingProfile {
  bool get isEnabled => trackingConfigurationFor(this).isEnabled;
}
