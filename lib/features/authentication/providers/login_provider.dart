import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_state.dart';
import '../models/login_result.dart';
import 'auth_service_provider.dart';

final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() {
    return const LoginState();
  }

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    // 🔹 Inicio del login
    state = state.copyWith(isLoading: true);
    clearError();

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      username: username,
      password: password,
    );

    // 🔹 Fin del login
    state = state.copyWith(isLoading: false);

    if (!result.isSuccess) {
      state = state.copyWith(errorMessage: result.message);
    }

    return result;
  }
}
