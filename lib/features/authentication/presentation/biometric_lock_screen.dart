import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biometric_unlock_provider.dart';
import '../providers/session_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String? _error;

  Future<void> _unlock() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });
    final unlocked = await ref.read(biometricUnlockProvider.notifier).unlock();
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    if (unlocked) {
      ref.read(sessionProvider.notifier).unlockWithBiometrics();
    } else {
      setState(() => _error = 'No fue posible verificar tu huella.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'MasiTrack bloqueado',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Usa tu huella para continuar. El seguimiento activo no se detiene.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isAuthenticating ? null : _unlock,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_isAuthenticating ? 'Verificando…' : 'Usar huella'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isAuthenticating
                        ? null
                        : () => ref.read(sessionProvider.notifier).useUsuarioAndPassword(),
                    child: const Text('Usar usuario y contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
