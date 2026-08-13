class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException({
    required this.message,
    this.code,
    this.cause,
  });

  @override
  String toString() {
    if (code != null) {
      return 'AppException($code): $message';
    }

    return 'AppException: $message';
  }
}