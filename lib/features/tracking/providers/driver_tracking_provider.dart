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
    this.lastSentAt,
    this.message,
  });

  final DriverTrackingStatus status;
  final DateTime? lastSentAt;
  final String? message;
}

final driverLocationDataSourceProvider = Provider<DriverLocationDataSource>((
  ref,
) {
  return DriverLocationDataSource(ref.watch(supabaseClientProvider));
});

final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  return DriverTrackingService();
});

final driverTrackingProvider =
    NotifierProvider<DriverTrackingNotifier, DriverTrackingState>(
      DriverTrackingNotifier.new,
    );

class DriverTrackingNotifier extends Notifier<DriverTrackingState> {
  static const _minimumSendInterval = Duration(seconds: 30);
  static const _minimumDistanceMeters = 30.0;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  DateTime? _lastAttemptAt;
  String? _trackedUserId;
  String? _sessionToken;
  bool _isInForeground = true;
  bool _isStarting = false;
  int _generation = 0;

  @override
  DriverTrackingState build() {
    ref.listen(sessionProvider, (_, next) {
      unawaited(_synchronizeSession(next.session));
    });
    ref.onDispose(_dispose);
    return const DriverTrackingState();
  }

  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {
    if (lifecycleState == AppLifecycleState.resumed) {
      _isInForeground = true;
      await _synchronizeSession(ref.read(sessionProvider).session);
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
    if (!_isInForeground || !_isEligibleDriver(session)) {
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
    state = const DriverTrackingState(status: DriverTrackingStatus.starting);

    try {
      final access = await ref
          .read(driverTrackingServiceProvider)
          .requestLocationAccess();
      if (!_isCurrentSession(generation, session)) {
        return;
      }

      switch (access) {
        case DriverLocationAccess.serviceDisabled:
          _setAccessState(
            DriverTrackingStatus.serviceDisabled,
            'Activa la ubicación para aparecer disponible en Fleet Control. Aparecerás como sin conexión para el supervisor.',
          );
          return;
        case DriverLocationAccess.permissionDenied:
          _setAccessState(
            DriverTrackingStatus.permissionDenied,
            'Fleet Control necesita permiso de ubicación para informar tu disponibilidad.',
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
          .getInitialPosition();
      if (!_isCurrentSession(generation, session)) {
        return;
      }

      await _sendPosition(initialPosition, force: true);
      if (!_isCurrentSession(generation, session)) {
        return;
      }

      _positionSubscription = ref
          .read(driverTrackingServiceProvider)
          .getPositionStream()
          .listen(
            (position) => unawaited(_sendPosition(position)),
            onError: (_) => _setTemporaryError(
              'Ubicación desactivada. Aparecerás como sin conexión para el supervisor.',
            ),
          );
    } on LocationServiceDisabledException {
      _setAccessState(
        DriverTrackingStatus.serviceDisabled,
        'Activa la ubicación para aparecer disponible en Fleet Control. Aparecerás como sin conexión para el supervisor.',
      );
    } on PermissionDeniedException {
      _setAccessState(
        DriverTrackingStatus.permissionDenied,
        'Fleet Control necesita permiso de ubicación para informar tu disponibilidad.',
      );
    } catch (_) {
      _setTemporaryError(
        'Ubicación desactivada. Aparecerás como sin conexión para el supervisor.',
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _sendPosition(Position position, {bool force = false}) async {
    if (_sessionToken == null || (!_shouldSend(position) && !force)) {
      return;
    }

    final attemptedAt = DateTime.now();
    _lastAttemptAt = attemptedAt;
    state = DriverTrackingState(
      status: DriverTrackingStatus.sending,
      lastSentAt: _lastSentAt,
    );

    try {
      await ref
          .read(driverLocationDataSourceProvider)
          .updateLocation(sessionToken: _sessionToken!, position: position);
      if (_sessionToken == null) {
        return;
      }

      _lastSentPosition = position;
      _lastSentAt = attemptedAt;
      state = DriverTrackingState(
        status: DriverTrackingStatus.active,
        lastSentAt: _lastSentAt,
      );
      if (kDebugMode) {
        debugPrint('driver-location sent: capturedAt=${attemptedAt.toUtc()}');
      }
    } on Failure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _stop(setIdleState: false);
        state = DriverTrackingState(
          status: DriverTrackingStatus.error,
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

  bool _shouldSend(Position position) {
    final now = DateTime.now();
    final lastAttemptAt = _lastAttemptAt;
    if (lastAttemptAt != null &&
        now.difference(lastAttemptAt) < _minimumSendInterval) {
      return false;
    }

    final lastSentPosition = _lastSentPosition;
    final lastSentAt = _lastSentAt;
    if (lastSentPosition == null || lastSentAt == null) {
      return true;
    }

    if (now.difference(lastSentAt) >= _minimumSendInterval) {
      return true;
    }

    return Geolocator.distanceBetween(
          lastSentPosition.latitude,
          lastSentPosition.longitude,
          position.latitude,
          position.longitude,
        ) >=
        _minimumDistanceMeters;
  }

  bool _isCurrentSession(int generation, AuthSession session) {
    return _isInForeground &&
        generation == _generation &&
        _trackedUserId == session.user.id &&
        _sessionToken == session.sessionToken;
  }

  void _setAccessState(DriverTrackingStatus status, String message) {
    state = DriverTrackingState(
      status: status,
      lastSentAt: _lastSentAt,
      message: message,
    );
  }

  void _setTemporaryError(String message) {
    state = DriverTrackingState(
      status: DriverTrackingStatus.error,
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
    _lastSentPosition = null;
    _lastSentAt = null;
    _lastAttemptAt = null;
    _trackedUserId = null;
    _sessionToken = null;
    if (setIdleState) {
      state = const DriverTrackingState();
    }
  }

  void _dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
