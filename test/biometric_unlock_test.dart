import 'package:fleet_control/features/authentication/data/session_storage.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/biometric_unlock_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/authentication/services/biometric_authenticator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('huella disponible se ofrece tras login y se activa sólo tras autenticar', () async {
    final storage = _MemorySessionStorage();
    final authenticator = _FakeBiometricAuthenticator(
      fingerprintAvailable: true,
      authenticateResult: true,
    );
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        biometricAuthenticatorProvider.overrideWithValue(authenticator),
      ],
    );
    addTearDown(container.dispose);

    await container.read(biometricUnlockProvider.notifier).prepareActivationOffer();
    expect(container.read(biometricUnlockProvider).offerActivation, isTrue);

    expect(await container.read(biometricUnlockProvider.notifier).enable(), isTrue);
    expect(storage.biometricUnlockEnabled, isTrue);
    expect(authenticator.authenticateCalls, 1);
  });

  test('sin huella no se ofrece ni bloquea una sesión restaurada', () async {
    final storage = _MemorySessionStorage()..biometricUnlockEnabled = true;
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        biometricAuthenticatorProvider.overrideWithValue(
          _FakeBiometricAuthenticator(fingerprintAvailable: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(biometricUnlockProvider.notifier).prepareActivationOffer();
    expect(container.read(biometricUnlockProvider).offerActivation, isFalse);
    expect(
      await container.read(biometricUnlockProvider.notifier).shouldLockRestoredSession(),
      isFalse,
    );
  });

  test('cancelar huella conserva la sesión bloqueada y su token', () {
    final session = AuthSession(
      user: const AuthenticatedUser(
        id: 'driver-1',
        roleId: 'role-1',
        role: 'chofer',
        nombre: 'Chofer',
        usuario: 'chofer',
        isActive: true,
      ),
      sessionToken: 'session-token',
      expiresAt: DateTime(2030),
    );

    final state = SessionState.biometricLocked(session);
    expect(state.isBiometricLocked, isTrue);
    expect(state.session?.sessionToken, 'session-token');
  });
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.fingerprintAvailable,
    this.authenticateResult = false,
  });

  final bool fingerprintAvailable;
  final bool authenticateResult;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticate() async {
    authenticateCalls += 1;
    return authenticateResult;
  }

  @override
  Future<bool> hasEnrolledFingerprint() async => fingerprintAvailable;
}

class _MemorySessionStorage implements SessionStorage {
  bool biometricUnlockEnabled = false;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<bool> readBiometricUnlockEnabled() async => biometricUnlockEnabled;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> writeBiometricUnlockEnabled(bool enabled) async {
    biometricUnlockEnabled = enabled;
  }
}
