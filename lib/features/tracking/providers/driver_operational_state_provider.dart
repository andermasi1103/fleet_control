import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../authentication/domain/entities/auth_session.dart';
import '../../authentication/providers/session_provider.dart';
import '../../managements/data/datasources/managements_data_source.dart';
import '../../managements/data/dtos/management_dto.dart';
import '../domain/driver_operational_state.dart';
import '../domain/tracking_profile.dart';
import 'driver_tracking_provider.dart';

class DriverOperationalStateSnapshot {
  const DriverOperationalStateSnapshot({
    this.operationalState,
    this.isLoading = false,
    this.hasKnownState = false,
    this.error,
  });

  final DriverOperationalState? operationalState;
  final bool isLoading;
  final bool hasKnownState;
  final String? error;

  TrackingProfile get trackingProfile =>
      trackingProfileForOperationalState(operationalState);

  DriverOperationalStateSnapshot copyWith({
    DriverOperationalState? operationalState,
    bool clearOperationalState = false,
    bool? isLoading,
    bool? hasKnownState,
    String? error,
    bool clearError = false,
  }) {
    return DriverOperationalStateSnapshot(
      operationalState: clearOperationalState
          ? null
          : operationalState ?? this.operationalState,
      isLoading: isLoading ?? this.isLoading,
      hasKnownState: hasKnownState ?? this.hasKnownState,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final driverOperationalStateProvider =
    NotifierProvider<
      DriverOperationalStateNotifier,
      DriverOperationalStateSnapshot
    >(DriverOperationalStateNotifier.new);

final _driverOperationalManagementsSourceProvider = Provider(
  (ref) => ManagementsDataSource(ref.watch(backendApiClientProvider)),
);

/// Keeps the backend-derived operational state alive independently of screens.
class DriverOperationalStateNotifier
    extends Notifier<DriverOperationalStateSnapshot> {
  int _generation = 0;

  @override
  DriverOperationalStateSnapshot build() {
    ref.listen(sessionProvider, (_, next) {
      _synchronizeForSession(next.session);
    });
    ref.listen(postLoginBootstrapProvider, (_, isReady) {
      if (isReady) {
        unawaited(refresh());
      } else {
        _clear();
      }
    });

    if (ref.read(postLoginBootstrapProvider) && _activeDriverSession != null) {
      Future.microtask(() => unawaited(refresh()));
    }
    return const DriverOperationalStateSnapshot();
  }

  AuthSession? get _activeDriverSession {
    if (!ref.read(postLoginBootstrapProvider)) return null;
    final session = ref.read(sessionProvider).session;
    if (session == null ||
        session.isExpired ||
        session.sessionToken.isEmpty ||
        session.user.role != 'chofer') {
      return null;
    }
    return session;
  }

  void _synchronizeForSession(AuthSession? session) {
    if (!ref.read(postLoginBootstrapProvider) ||
        session == null ||
        session.isExpired ||
        session.user.role != 'chofer') {
      _clear();
      return;
    }
    unawaited(refresh());
  }

  /// Refreshes from the Fastify source of truth after login, resume and retry.
  Future<void> refresh() async {
    final session = _activeDriverSession;
    if (session == null) {
      _clear();
      return;
    }

    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final managements = await ref
          .read(_driverOperationalManagementsSourceProvider)
          .list(session.sessionToken);
      if (!_isCurrentSession(generation, session)) return;

      _publish(
        driverOperationalStateFromManagementStatuses(
          managements.map((management) => management.managementStatus),
        ),
        hasKnownState: true,
      );
    } catch (_) {
      if (!_isCurrentSession(generation, session)) return;

      // A network failure never promotes a driver to active-trip. It preserves
      // the last known state, or uses available until the first sync succeeds.
      _publish(
        state.operationalState ?? DriverOperationalState.available,
        hasKnownState: state.hasKnownState,
        error: 'No fue posible actualizar el estado operativo.',
      );
    } finally {
      if (_isCurrentSession(generation, session)) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Applies the management returned by a successful claim or status change.
  void updateFromManagement(ManagementDto management) {
    if (_activeDriverSession == null) return;

    ++_generation;
    _publish(
      driverOperationalStateFromManagementStatus(management.managementStatus),
      hasKnownState: true,
      isLoading: false,
    );
  }

  void _publish(
    DriverOperationalState operationalState, {
    required bool hasKnownState,
    String? error,
    bool? isLoading,
  }) {
    final previousProfile = state.trackingProfile;
    state = DriverOperationalStateSnapshot(
      operationalState: operationalState,
      isLoading: isLoading ?? state.isLoading,
      hasKnownState: hasKnownState,
      error: error,
    );
    _setTrackingProfileIfChanged(previousProfile, state.trackingProfile);
  }

  void _clear() {
    ++_generation;
    final previousProfile = state.trackingProfile;
    state = const DriverOperationalStateSnapshot();
    _setTrackingProfileIfChanged(previousProfile, TrackingProfile.idle);
  }

  bool _isCurrentSession(int generation, AuthSession session) {
    final current = _activeDriverSession;
    return generation == _generation &&
        current != null &&
        current.user.id == session.user.id &&
        current.sessionToken == session.sessionToken;
  }

  void _setTrackingProfileIfChanged(
    TrackingProfile previous,
    TrackingProfile next,
  ) {
    if (previous == next) return;
    unawaited(ref.read(driverTrackingProvider.notifier).setProfile(next));
  }
}
