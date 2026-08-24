import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../data/datasources/supabase_auth_data_source.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/authenticated_user.dart';
import 'session_state.dart';

final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(ref.watch(supabaseClientProvider));
});

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  bool _isSigningOut = false;

  @override
  SessionState build() {
    return const SessionState.unauthenticated();
  }

  Future<void> signInWithUsuarioAndPassword({
    required String usuario,
    required String password,
  }) async {
    state = const SessionState.initializing();

    try {
      final loginResponse = await ref
          .read(supabaseAuthDataSourceProvider)
          .signInWithUsuarioAndPassword(usuario: usuario, password: password);

      final session = AuthSession(
        user: loginResponse.user.toDomain(),
        sessionToken: loginResponse.sessionToken,
        expiresAt: loginResponse.expiresAt,
      );

      if (session.isExpired) {
        throw const Failure(
          message: 'La sesión recibida ya venció. Intenta nuevamente.',
          type: FailureType.sessionExpired,
        );
      }

      state = SessionState.authenticated(session);
    } on Failure catch (error) {
      state = SessionState.unauthenticated(errorMessage: error.message);
      rethrow;
    } catch (_) {
      const failure = Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        type: FailureType.supabase,
      );

      state = const SessionState.unauthenticated(
        errorMessage: 'No fue posible iniciar sesión. Intenta nuevamente.',
      );

      throw failure;
    }
  }

  Future<void> signOut() async {
    if (_isSigningOut) {
      return;
    }

    _isSigningOut = true;
    final sessionToken = state.session?.sessionToken;

    try {
      if (sessionToken != null && sessionToken.isNotEmpty) {
        await ref
            .read(supabaseAuthDataSourceProvider)
            .signOut(sessionToken: sessionToken);
      }
    } catch (_) {
      // La revocación remota puede fallar sin red o si el backend no responde.
      // Nunca debe impedir la salida local del usuario.
      if (kDebugMode) {
        debugPrint('session-logout request failed');
      }
    } finally {
      localSignOut();
      _isSigningOut = false;
    }
  }

  /// Replaces only the user profile stored in the current in-memory session.
  /// The opaque session token and its expiry deliberately remain untouched.
  void updateCurrentUser(AuthenticatedUser updatedUser) {
    final currentSession = state.session;
    if (currentSession == null || currentSession.user.id != updatedUser.id) {
      return;
    }
    state = SessionState.authenticated(
      AuthSession(
        user: updatedUser,
        sessionToken: currentSession.sessionToken,
        expiresAt: currentSession.expiresAt,
      ),
    );
  }

  /// Clears the in-memory session without calling a remote endpoint.
  ///
  /// This is used after a password change because that operation revokes the
  /// current token before the client can attempt a regular remote sign-out.
  void localSignOut() {
    state = const SessionState.unauthenticated();
  }
}
