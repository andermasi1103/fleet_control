class Failure {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  String toString() {
    if (code != null) {
      return 'Failure($code): $message';
    }

    return 'Failure: $message';
  }
}