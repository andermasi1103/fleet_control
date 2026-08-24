class LoginResult {
  const LoginResult({
    required this.isSuccess,
    this.message,
  });

  final bool isSuccess;
  final String? message;
}
