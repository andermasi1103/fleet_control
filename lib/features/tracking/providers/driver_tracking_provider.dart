import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../services/native_driver_tracking_service.dart';

enum DriverTrackingStatus {
  idle,
  starting,
  active,
  sending,
  permissionDenied,
  permissionDeniedForever,
  notificationsBlocked,
  serviceDisabled,
  error,
}

class DriverTrackingState {
  const DriverTrackingState({
    this.status = DriverTrackingStatus.idle,
    this.profile = TrackingProfile.idle,
    this.isTrackingRequested = false,
    this.lastSentAt,
    this.message,
  });

  final DriverTrackingStatus status;
  final TrackingProfile profile;
  final bool isTrackingRequested;
  final DateTime? lastSentAt;
  final String? message;
}

final driverLocationDataSourceProvider = Provider<DriverLocationDataSource>((ref) {
  return DriverLocationDataSource(ref.watch(backendApiClientProvider));
});

final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  return DriverTrackingService();
});

final nativeDriverTrackingGatewayProvider = Provider<NativeDriverTrackingGateway>((ref) {
  return const MethodChannelNativeDriverTrackingGateway();
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
  String? _sessionToken;
  TrackingProfile _profile = TrackingProfile.idle;
  bool _isInForeground = true;
  bool _isStarting = false;
  bool _isTrackingRequested = false;
  int _generation = 0;

  bool get _usesNativeAndroidService =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  DriverTrackingState build() {
    _forceGpsScheduler = DriverForceGpsScheduler(
      requestGps: _requestForcedPosition,
    );
    ref.listen(sessionProvider, (_, next) {
      unawaited(_synchronizeSession(next.session));
    });
    ref.listen(postLoginBootstrapProvider, (_, isReady) {
      if (isReady) {
        unawaited(_synchronizeSession(ref.read(sessionProvider).session));
        unawaited(_recoverNativeStatus());
      } else {
        unawaited(_stop(setIdleState: true, clearTrackingRequest: true));
      }
    });
    if (ref.read(postLoginBootstrapProvider)) {
      Future.microtask(() {
        unawaited(_synchronizeSession(ref.read(sessionProvider).session));
        unawaited(_recoverNativeStatus());
      });
    }
    ref.onDispose(_dispose);
    return DriverTrackingState(profile: _profile);
  }

  /// Starts only after an explicit, visible action from the driver.
  Future<void> startTracking() async {
    final session = ref.read(sessionProvider).session;
    if (!_isEligibleDriver(session)) {
      _setState(
        status: DriverTrackingStatus.error,
        message: 'Inicia sesión como chofer para activar el seguimiento.',
      );
      return;
    }
    if (!_profile.isEnabled) _profile = TrackingProfile.available;
    _setState(status: DriverTrackingStatus.starting);

    final access = await ref
        .read(driverTrackingServiceProvider)
        .requestLocationAccess();
    switch (access) {
      case DriverLocationAccess.serviceDisabled:
        _setState(
          status: DriverTrackingStatus.serviceDisabled,
          message: 'Activa la ubicación para iniciar el seguimiento.',
        );
        return;
      case DriverLocationAccess.permissionDenied:
        _setState(
          status: DriverTrackingStatus.permissionDenied,
          message: 'MasiTrack necesita permiso de ubicación para iniciar el seguimiento.',
        );
        return;
      case DriverLocationAccess.permissionDeniedForever:
        _setState(
          status: DriverTrackingStatus.permissionDeniedForever,
          message: 'El permiso de ubicación está bloqueado. Habilítalo desde la configuración del dispositivo.',
        );
        return;
      case DriverLocationAccess.granted:
        break;
    }

    _isTrackingRequested = true;
    if (_usesNativeAndroidService) {
      await _startNative(session!);
    } else {
      await _startDart(session!);
    }
  }

  Future<void> stopTracking() =>
      _stop(setIdleState: true, clearTrackingRequest: true);

  /// Operational state changes only update an already explicit tracking session.
  Future<void> setProfile(TrackingProfile profile) async {
    if (_profile == profile) return;
    _profile = profile;
    if (!_profile.isEnabled) {
      await _stop(setIdleState: true, clearTrackingRequest: true);
      return;
    }
    if (!_isTrackingRequested) {
      _setState(status: DriverTrackingStatus.idle);
      return;
    }
    if (_usesNativeAndroidService) {
      try {
        final nativeState = await ref
            .read(nativeDriverTrackingGatewayProvider)
            .updateProfile(NativeDriverTrackingProfileUpdate(_profile));
        _applyNativeState(nativeState);
      } catch (_) {
        _setState(
          status: DriverTrackingStatus.error,
          message: 'No fue posible actualizar el perfil de seguimiento.',
        );
      }
      return;
    }
    await _synchronizeSession(ref.read(sessionProvider).session);
  }

  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {
    if (lifecycleState == AppLifecycleState.resumed) {
      _isInForeground = true;
      await _recoverNativeStatus();
      await _synchronizeSession(ref.read(sessionProvider).session);
      return;
    }
    if (_usesNativeAndroidService) return;
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _isInForeground = false;
      await _stop(setIdleState: true, clearTrackingRequest: false);
    }
  }

  Future<void> _synchronizeSession(AuthSession? session) async {
    if (!_isEligibleDriver(session)) {
      await _stop(setIdleState: true, clearTrackingRequest: true);
      return;
    }
    if (!_isTrackingRequested) {
      _setState(status: DriverTrackingStatus.idle);
      return;
    }
    if (_usesNativeAndroidService) return;
    if (!_isInForeground || _isStarting || _positionSubscription != null) return;
    await _startDart(session!);
  }

  bool _isEligibleDriver(AuthSession? session) {
    return ref.read(postLoginBootstrapProvider) &&
        session != null &&
        !session.isExpired &&
        session.sessionToken.isNotEmpty &&
        session.user.role == 'chofer';
  }

  Future<void> _startNative(AuthSession session) async {
    try {
      final nativeState = await ref.read(nativeDriverTrackingGatewayProvider).start(
            NativeDriverTrackingStartRequest(
              sessionToken: session.sessionToken,
              backendApiBaseUrl: ref.read(appConfigProvider).backendApiBaseUrl,
              profile: _profile,
            ),
          );
      _applyNativeState(nativeState);
      if (nativeState.status == NativeDriverTrackingStatus.starting) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          unawaited(_recoverNativeStatus());
        });
      }
    } on PlatformException catch (error) {
      _isTrackingRequested = false;
      if (error.code == 'notifications_blocked') {
        _setState(
          status: DriverTrackingStatus.notificationsBlocked,
          message: 'Habilita las notificaciones para mostrar el seguimiento activo durante tu jornada.',
        );
      } else if (error.code == 'location_permission_denied') {
        _setState(
          status: DriverTrackingStatus.permissionDenied,
          message: 'MasiTrack necesita permiso de ubicación para iniciar el seguimiento.',
        );
      } else {
        _setState(
          status: DriverTrackingStatus.error,
          message: 'No fue posible iniciar el seguimiento.',
        );
      }
    } catch (_) {
      _isTrackingRequested = false;
      _setState(
        status: DriverTrackingStatus.error,
        message: 'No fue posible iniciar el seguimiento.',
      );
    }
  }

  Future<void> _recoverNativeStatus() async {
    if (!_usesNativeAndroidService ||
        !_isEligibleDriver(ref.read(sessionProvider).session)) {
      return;
    }
    try {
      final nativeState = await ref
          .read(nativeDriverTrackingGatewayProvider)
          .getStatus();
      if (nativeState.isActive) _isTrackingRequested = true;
      if (nativeState.status != NativeDriverTrackingStatus.idle ||
          _isTrackingRequested) {
        _applyNativeState(nativeState);
      }
    } catch (_) {
      // No platform channel exists in Dart unit tests or non-Android hosts.
    }
  }

  void _applyNativeState(NativeDriverTrackingState nativeState) {
    final status = switch (nativeState.status) {
      NativeDriverTrackingStatus.starting => DriverTrackingStatus.starting,
      NativeDriverTrackingStatus.active => DriverTrackingStatus.active,
      NativeDriverTrackingStatus.error => DriverTrackingStatus.error,
      NativeDriverTrackingStatus.idle => DriverTrackingStatus.idle,
    };
    if (nativeState.profile.isEnabled) _profile = nativeState.profile;
    _setState(status: status, message: nativeState.message);
  }

  Future<void> _startDart(AuthSession session) async {
    if (_isStarting || _positionSubscription != null) return;
    _isStarting = true;
    final generation = ++_generation;
    _sessionToken = session.sessionToken;
    _setState(status: DriverTrackingStatus.starting);
    try {
      final initialPosition = await ref
          .read(driverTrackingServiceProvider)
          .getCurrentPosition(_profile);
      if (!_isCurrentDartSession(generation, session)) return;
      await _sendOrBuffer(initialPosition, force: true);
      if (!_isCurrentDartSession(generation, session)) return;
      _positionSubscription = ref
          .read(driverTrackingServiceProvider)
          .getPositionStream(_profile)
          .listen(
            (position) => unawaited(_sendOrBuffer(position)),
            onError: (_) => _setState(
              status: DriverTrackingStatus.error,
              message: 'Ubicación desactivada. El seguimiento se reanudará al corregirlo.',
            ),
          );
      _forceGpsScheduler.configure(
        profile: _profile,
        isInForeground: _isInForeground,
      );
    } on LocationServiceDisabledException {
      _setState(
        status: DriverTrackingStatus.serviceDisabled,
        message: 'Activa la ubicación para iniciar el seguimiento.',
      );
    } on PermissionDeniedException {
      _setState(
        status: DriverTrackingStatus.permissionDenied,
        message: 'MasiTrack necesita permiso de ubicación.',
      );
    } catch (_) {
      _setState(
        status: DriverTrackingStatus.error,
        message: 'No fue posible iniciar el seguimiento.',
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _requestForcedPosition(DateTime dueAt) async {
    final generation = _generation;
    if (!_profile.isEnabled || !_isInForeground || _sessionToken == null) return;
    try {
      final position = await ref
          .read(driverTrackingServiceProvider)
          .getCurrentPosition(_profile);
      if (generation == _generation && _lastSentBefore(dueAt)) {
        await _sendOrBuffer(position, force: true);
      }
    } catch (_) {
      _setState(
        status: DriverTrackingStatus.error,
        message: 'No fue posible obtener una ubicación GPS actual.',
      );
    }
  }

  bool _lastSentBefore(DateTime dueAt) =>
      _lastSentAt == null || _lastSentAt!.isBefore(dueAt);

  Future<void> _sendOrBuffer(Position position, {bool force = false}) async {
    final validation = _positionPolicy.validate(
      position,
      profile: _profile,
      now: DateTime.now(),
    );
    if (validation != null ||
        !_backpressure.startOrBuffer(position, force: force)) {
      _logRejectedPosition(validation);
      return;
    }
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
    final token = _sessionToken;
    if (token == null || rejection != null) {
      _logRejectedPosition(rejection);
      return;
    }
    _setState(status: DriverTrackingStatus.sending);
    try {
      await ref
          .read(driverLocationDataSourceProvider)
          .updateLocation(sessionToken: token, position: position);
      if (_sessionToken != token || generation != _generation) return;
      _lastSentPosition = position;
      _lastSentAt = DateTime.now();
      _forceGpsScheduler.noteLocationSent();
      _setState(status: DriverTrackingStatus.active, lastSentAt: _lastSentAt);
      if (kDebugMode) debugPrint('tracking: location sent');
    } on Failure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _stop(setIdleState: false, clearTrackingRequest: true);
        _setState(status: DriverTrackingStatus.error, message: error.message);
      } else {
        _setState(
          status: DriverTrackingStatus.error,
          message: 'Error temporal al actualizar la ubicación.',
        );
      }
    } catch (_) {
      _setState(
        status: DriverTrackingStatus.error,
        message: 'Error temporal al actualizar la ubicación.',
      );
    }
  }

  bool _isCurrentDartSession(int generation, AuthSession session) =>
      _isTrackingRequested &&
      _isInForeground &&
      generation == _generation &&
      _sessionToken == session.sessionToken;

  void _logRejectedPosition(PositionRejectionReason? reason) {
    if (kDebugMode && reason != null) {
      debugPrint('tracking: location ignored=${reason.name}');
    }
  }

  void _setState({
    required DriverTrackingStatus status,
    DateTime? lastSentAt,
    String? message,
  }) {
    state = DriverTrackingState(
      status: status,
      profile: _profile,
      isTrackingRequested: _isTrackingRequested,
      lastSentAt: lastSentAt ?? _lastSentAt,
      message: message,
    );
  }

  Future<void> _stop({
    required bool setIdleState,
    required bool clearTrackingRequest,
  }) async {
    ++_generation;
    _isStarting = false;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    _forceGpsScheduler.stop();
    _backpressure.reset();
    if (_usesNativeAndroidService) {
      try {
        await ref.read(nativeDriverTrackingGatewayProvider).stop();
      } catch (_) {
        // Local logout must not depend on a platform callback.
      }
    }
    _lastSentPosition = null;
    _lastSentAt = null;
    _sessionToken = null;
    if (clearTrackingRequest) _isTrackingRequested = false;
    if (setIdleState) _setState(status: DriverTrackingStatus.idle);
  }

  void _dispose() {
    _positionSubscription?.cancel();
    _forceGpsScheduler.dispose();
    _backpressure.reset();
  }
}

extension on TrackingProfile {
  bool get isEnabled => trackingConfigurationFor(this).isEnabled;
}
