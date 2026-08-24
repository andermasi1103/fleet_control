import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/login_result.dart';
import 'login_state.dart';
import 'session_provider.dart';

final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<LoginResult> login({
    required String usuario,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    clearError();

    try {
      await ref.read(sessionProvider.notifier).signInWithUsuarioAndPassword(
            usuario: usuario,
            password: password,
          );
      state = state.copyWith(isLoading: false);
      return const LoginResult(isSuccess: true, message: 'Login exitoso');
    } catch (_) {
      final message = ref.read(sessionProvider).errorMessage ??
          'No fue posible iniciar sesión.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      return LoginResult(isSuccess: false, message: message);
    }
  }
}
