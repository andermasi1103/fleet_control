import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> hasEnrolledFingerprint();

  Future<bool> authenticate();
}

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? localAuthentication])
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> hasEnrolledFingerprint() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (!await _localAuthentication.canCheckBiometrics) return false;
      final biometrics = await _localAuthentication.getAvailableBiometrics();
      return biometrics.contains(BiometricType.fingerprint);
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Usa tu huella para ingresar a MasiTrack',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
