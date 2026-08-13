import '../../users/models/user_model.dart';

class UserSession {
  final UserModel user;
  final DateTime loginAt;
  final DateTime? lastActivity;
  final bool rememberSession;

  const UserSession({
    required this.user,
    required this.loginAt,
    this.lastActivity,
    this.rememberSession = false,
  });

  UserSession copyWith({
    UserModel? user,
    DateTime? loginAt,
    DateTime? lastActivity,
    bool? rememberSession,
  }) {
    return UserSession(
      user: user ?? this.user,
      loginAt: loginAt ?? this.loginAt,
      lastActivity: lastActivity ?? this.lastActivity,
      rememberSession:
          rememberSession ?? this.rememberSession,
    );
  }
}