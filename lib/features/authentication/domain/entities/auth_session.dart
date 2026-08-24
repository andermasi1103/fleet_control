import 'authenticated_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.sessionToken,
    required this.expiresAt,
  });

  final AuthenticatedUser user;
  final String sessionToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
