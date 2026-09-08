import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/biometric_authenticator.dart';
import 'session_provider.dart';

class BiometricUnlockState {
  const BiometricUnlockState({
    this.isEnabled = false,
    this.fingerprintAvailable = false,
    this.offerActivation = false,
  });

  final bool isEnabled;
  final bool fingerprintAvailable;
  final bool offerActivation;

  BiometricUnlockState copyWith({
    bool? isEnabled,
    bool? fingerprintAvailable,
    bool? offerActivation,
  }) => BiometricUnlockState(
    isEnabled: isEnabled ?? this.isEnabled,
    fingerprintAvailable: fingerprintAvailable ?? this.fingerprintAvailable,
    offerActivation: offerActivation ?? this.offerActivation,
  );
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) {
  return LocalAuthBiometricAuthenticator();
});

final biometricUnlockProvider =
    NotifierProvider<BiometricUnlockNotifier, BiometricUnlockState>(
      BiometricUnlockNotifier.new,
    );

class BiometricUnlockNotifier extends Notifier<BiometricUnlockState> {
  @override
  BiometricUnlockState build() {
    Future.microtask(refresh);
    return const BiometricUnlockState();
  }

  Future<void> refresh() async {
    final storage = ref.read(sessionStorageProvider);
    final authenticator = ref.read(biometricAuthenticatorProvider);
    final enabled = await storage.readBiometricUnlockEnabled();
    final fingerprintAvailable = await authenticator.hasEnrolledFingerprint();
    state = BiometricUnlockState(
      isEnabled: enabled,
      fingerprintAvailable: fingerprintAvailable,
    );
  }

  Future<bool> shouldLockRestoredSession() async {
    final storage = ref.read(sessionStorageProvider);
    final authenticator = ref.read(biometricAuthenticatorProvider);
    return await storage.readBiometricUnlockEnabled() &&
        await authenticator.hasEnrolledFingerprint();
  }

  Future<void> prepareActivationOffer() async {
    await refresh();
    if (!state.isEnabled && state.fingerprintAvailable) {
      state = state.copyWith(offerActivation: true);
    }
  }

  void dismissOffer() {
    state = state.copyWith(offerActivation: false);
  }

  Future<bool> enable() async {
    if (!await ref.read(biometricAuthenticatorProvider).authenticate()) {
      return false;
    }
    await ref.read(sessionStorageProvider).writeBiometricUnlockEnabled(true);
    state = state.copyWith(isEnabled: true, offerActivation: false);
    return true;
  }

  Future<void> disable() async {
    await ref.read(sessionStorageProvider).writeBiometricUnlockEnabled(false);
    state = state.copyWith(isEnabled: false, offerActivation: false);
  }

  Future<bool> unlock() => ref.read(biometricAuthenticatorProvider).authenticate();
}
