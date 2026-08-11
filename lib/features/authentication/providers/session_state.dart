import '../models/user_session.dart';
  import '../../../core/constants/app_constants.dart';

class SessionState {
  final UserSession? session;

  const SessionState({this.session});

  /// 🔹 Estado de autenticación
  bool get isAuthenticated => session != null;

  /// 🔹 Roles soportados
  bool get isAdmin => session?.user.rol == AppConstants.adminRole;
  bool get isSupervisor => session?.user.rol == AppConstants.supervisorRole;
  bool get isChofer => session?.user.rol == AppConstants.choferRole;
  bool get isUser => session?.user.rol == AppConstants.userRole;

  /// 🔹 Copia segura del estado
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
