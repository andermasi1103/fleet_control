import '../domain/entities/auth_session.dart';

enum SessionStatus {
  initializing,
  authenticated,
  biometricLocked,
  passwordLogin,
  unauthenticated,
  failure,
}

class SessionState {
  const SessionState._({
    required this.status,
    this.session,
    this.errorMessage,
  });

  const SessionState.initializing()
      : this._(status: SessionStatus.initializing);

  const SessionState.authenticated(AuthSession session)
      : this._(
          status: SessionStatus.authenticated,
          session: session,
        );

  const SessionState.biometricLocked(AuthSession session)
      : this._(
          status: SessionStatus.biometricLocked,
          session: session,
        );

  const SessionState.passwordLogin(AuthSession session)
      : this._(
          status: SessionStatus.passwordLogin,
          session: session,
        );

  const SessionState.unauthenticated({String? errorMessage})
      : this._(
          status: SessionStatus.unauthenticated,
          errorMessage: errorMessage,
        );

  const SessionState.failure(String errorMessage)
      : this._(
          status: SessionStatus.failure,
          errorMessage: errorMessage,
        );

  final SessionStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  bool get isBiometricLocked => status == SessionStatus.biometricLocked;

  bool get isInitializing => status == SessionStatus.initializing;

  bool get isUnauthenticated => status == SessionStatus.unauthenticated;

  bool get hasError => errorMessage != null;
}
