import '../models/user_session.dart';

class SessionState {
  final UserSession? session;

  const SessionState({
    this.session,
  });

  bool get isAuthenticated =>
      session != null;

  bool get isAdmin =>
      session?.user.isAdmin ?? false;

  bool get isSupervisor =>
      session?.user.isSupervisor ?? false;

  bool get isChofer =>
      session?.user.isChofer ?? false;

  bool get isUser =>
      session?.user.isUser ?? false;

  UserSession? get currentSession =>
      session;

  SessionState copyWith({
    Object? session = _sentinel,
  }) {
    return SessionState(
      session: identical(session, _sentinel)
          ? this.session
          : session as UserSession?,
    );
  }

  static const _sentinel = Object();
}