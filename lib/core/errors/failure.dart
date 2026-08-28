enum FailureType {
  invalidCredentials,
  sessionExpired,
  userNotFound,
  userInactive,
  network,
  backend,
  traccar,
  timeout,
  rateLimited,
  insufficientPermissions,
  configuration,
  unknown,
}

class Failure implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final FailureType type;

  const Failure({
    required this.message,
    this.code,
    this.statusCode,
    this.type = FailureType.unknown,
  });

  @override
  String toString() {
    if (code != null) {
      return 'Failure(${type.name}, $code): $message';
    }

    return 'Failure(${type.name}): $message';
  }
}
