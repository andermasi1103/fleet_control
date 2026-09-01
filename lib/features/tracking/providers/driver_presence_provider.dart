import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../authentication/domain/entities/auth_session.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/driver_presence_data_source.dart';
import '../domain/tracking_profile.dart';
import '../services/driver_presence_controller.dart';
import 'driver_operational_state_provider.dart';

class DriverPresenceState {
  const DriverPresenceState({
    this.profile = TrackingProfile.idle,
    this.isActive = false,
  });

  final TrackingProfile profile;
  final bool isActive;
}

final driverPresenceDataSourceProvider = Provider<DriverPresenceDataSource>((
  ref,
) {
  return DriverPresenceDataSource(ref.watch(backendApiClientProvider));
});

final driverPresenceProvider =
    NotifierProvider<DriverPresenceNotifier, DriverPresenceState>(
      DriverPresenceNotifier.new,
    );

class DriverPresenceNotifier extends Notifier<DriverPresenceState> {
  late final DriverPresenceController _controller;
  TrackingProfile _profile = TrackingProfile.idle;
  bool _isInForeground = true;

  @override
  DriverPresenceState build() {
    _controller = DriverPresenceController(
      sendHeartbeat: (sessionToken) => ref
          .read(driverPresenceDataSourceProvider)
          .heartbeat(sessionToken: sessionToken),
    );
    _profile = ref.read(driverOperationalStateProvider).trackingProfile;
    ref.listen(sessionProvider, (_, _) => _configure());
    ref.listen(postLoginBootstrapProvider, (_, _) => _configure());
    ref.listen(driverOperationalStateProvider, (_, next) {
      _profile = next.trackingProfile;
      _configure();
    });
    ref.onDispose(_controller.dispose);
    Future.microtask(_configure);
    return DriverPresenceState(profile: _profile);
  }

  Future<void> handleLifecycleChange(AppLifecycleState lifecycleState) async {
    _isInForeground = lifecycleState == AppLifecycleState.resumed;
    _configure();
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

  void _configure() {
    final session = _activeDriverSession;
    _controller.configure(
      sessionToken: session?.sessionToken,
      profile: _profile,
      isInForeground: _isInForeground,
    );
    state = DriverPresenceState(
      profile: _profile,
      isActive: _controller.isActive,
    );
  }
}
