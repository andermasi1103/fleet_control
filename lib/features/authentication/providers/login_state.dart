class LoginState {
  final bool isLoading;
  final bool obscurePassword;
  final String? errorMessage;

  const LoginState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.errorMessage,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    String? errorMessage,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      // 🔹 Aquí usamos directamente el valor recibido
      errorMessage: errorMessage,
    );
  }
}
