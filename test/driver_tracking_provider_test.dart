import 'package:fleet_control/features/authentication/data/session_storage.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/tracking/domain/tracking_profile.dart';
import 'package:fleet_control/features/tracking/providers/driver_tracking_provider.dart';
import 'package:fleet_control/features/tracking/services/driver_tracking_service.dart';
import 'package:fleet_control/features/tracking/services/native_driver_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android starts only after the explicit tracking action', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = _FakeNativeTrackingGateway();
    final container = _container(native: native);
    addTearDown(container.dispose);
    container.read(postLoginBootstrapProvider.notifier).state = true;
    container.read(driverTrackingProvider);

    await Future<void>.delayed(Duration.zero);

    expect(native.starts, isEmpty);
    await container.read(driverTrackingProvider.notifier).startTracking();

    expect(native.starts, hasLength(1));
    expect(native.starts.single.profile, TrackingProfile.available);
    expect(container.read(driverTrackingProvider).isTrackingRequested, isTrue);
  });

  test('Android updates only the native profile during an active journey', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = _FakeNativeTrackingGateway();
    final container = _container(native: native);
    addTearDown(container.dispose);
    container.read(postLoginBootstrapProvider.notifier).state = true;
    container.read(driverTrackingProvider);

    await container.read(driverTrackingProvider.notifier).startTracking();
    await container
        .read(driverTrackingProvider.notifier)
        .setProfile(TrackingProfile.activeTrip);

    expect(native.profileUpdates, [TrackingProfile.activeTrip]);
  });

  test('logout stops native Android tracking', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = _FakeNativeTrackingGateway();
    final container = _container(native: native);
    addTearDown(container.dispose);
    container.read(postLoginBootstrapProvider.notifier).state = true;
    container.read(driverTrackingProvider);
    await container.read(driverTrackingProvider.notifier).startTracking();

    container.read(sessionProvider.notifier).localSignOut();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(native.stopCalls, greaterThanOrEqualTo(1));
    expect(container.read(driverTrackingProvider).isTrackingRequested, isFalse);
  });

  test('location permission rejection does not start native tracking', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = _FakeNativeTrackingGateway();
    final container = _container(
      native: native,
      access: DriverLocationAccess.permissionDenied,
    );
    addTearDown(container.dispose);
    container.read(postLoginBootstrapProvider.notifier).state = true;
    container.read(driverTrackingProvider);

    await container.read(driverTrackingProvider.notifier).startTracking();

    expect(native.starts, isEmpty);
    expect(
      container.read(driverTrackingProvider).status,
      DriverTrackingStatus.permissionDenied,
    );
  });
}

ProviderContainer _container({
  required _FakeNativeTrackingGateway native,
  DriverLocationAccess access = DriverLocationAccess.granted,
}) {
  return ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      sessionStorageProvider.overrideWithValue(_MemorySessionStorage()),
      driverTrackingServiceProvider.overrideWithValue(
        _FakeDriverTrackingService(access),
      ),
      nativeDriverTrackingGatewayProvider.overrideWithValue(native),
    ],
  );
}

class _FakeDriverTrackingService extends DriverTrackingService {
  _FakeDriverTrackingService(this.access);

  final DriverLocationAccess access;

  @override
  Future<DriverLocationAccess> requestLocationAccess() async => access;
}

class _FakeNativeTrackingGateway implements NativeDriverTrackingGateway {
  final starts = <NativeDriverTrackingStartRequest>[];
  final profileUpdates = <TrackingProfile>[];
  int stopCalls = 0;

  @override
  Future<NativeDriverTrackingState> getStatus() async =>
      const NativeDriverTrackingState.idle();

  @override
  Future<NativeDriverTrackingState> start(
    NativeDriverTrackingStartRequest request,
  ) async {
    starts.add(request);
    return NativeDriverTrackingState(
      status: NativeDriverTrackingStatus.active,
      profile: request.profile,
    );
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<NativeDriverTrackingState> updateProfile(
    NativeDriverTrackingProfileUpdate update,
  ) async {
    profileUpdates.add(update.profile);
    return NativeDriverTrackingState(
      status: NativeDriverTrackingStatus.active,
      profile: update.profile,
    );
  }
}

class _AuthenticatedSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => SessionState.authenticated(
    AuthSession(
      user: const AuthenticatedUser(
        id: 'driver-1',
        roleId: 'role-driver',
        role: 'chofer',
        nombre: 'Chofer',
        usuario: 'chofer',
        isActive: true,
      ),
      sessionToken: 'session-token',
      expiresAt: DateTime(2030),
    ),
  );
}

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<bool> readBiometricUnlockEnabled() async => false;

  @override
  Future<void> writeBiometricUnlockEnabled(bool enabled) async {}
}
