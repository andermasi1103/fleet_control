import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../role_views/providers/current_user_views_provider.dart';
import '../data/session_storage.dart';
import '../data/datasources/fastify_auth_data_source.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/authenticated_user.dart';
import 'session_state.dart';

final fastifyAuthDataSourceProvider = Provider<FastifyAuthDataSource>((ref) {
  return FastifyAuthDataSource(ref.watch(backendApiClientProvider));
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SecureSessionStorage();
});

/// Se habilita al terminar el bootstrap protegido con Fastify.
final postLoginBootstrapProvider = StateProvider<bool>((ref) => false);

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  bool _isSigningOut = false;

  @override
  SessionState build() {
    ref.read(postLoginBootstrapProvider.notifier).state = false;
    Future.microtask(_restoreSession);
    return const SessionState.initializing();
  }

  Future<void> signInWithUsuarioAndPassword({
    required String usuario,
    required String password,
  }) async {
    ref.read(postLoginBootstrapProvider.notifier).state = false;
    state = const SessionState.initializing();

    try {
      final loginResponse = await ref
          .read(fastifyAuthDataSourceProvider)
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

      await ref.read(sessionStorageProvider).write(session);
      await _activateAuthenticatedSession(session);
    } on Failure catch (error) {
      ref.read(postLoginBootstrapProvider.notifier).state = false;
      state = SessionState.unauthenticated(errorMessage: error.message);
      rethrow;
    } catch (_) {
      ref.read(postLoginBootstrapProvider.notifier).state = false;
      const failure = Failure(
        message: 'No fue posible iniciar sesión. Intenta nuevamente.',
        type: FailureType.network,
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
            .read(pushNotificationServiceProvider)
            .deactivate(sessionToken);
        await ref
            .read(fastifyAuthDataSourceProvider)
            .signOut(sessionToken: sessionToken);
      }
    } catch (_) {
      // La revocación remota puede fallar sin red o si el backend no responde.
      // Nunca debe impedir la salida local del usuario.
      if (kDebugMode) {
        debugPrint('session-logout request failed');
      }
    } finally {
      await _clearStoredSession();
      _setUnauthenticated();
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
    final updatedSession = AuthSession(
      user: updatedUser,
      sessionToken: currentSession.sessionToken,
      expiresAt: currentSession.expiresAt,
    );
    state = SessionState.authenticated(updatedSession);
    unawaited(_persistUpdatedSession(updatedSession));
  }

  /// Clears the in-memory session without calling a remote endpoint.
  ///
  /// This is used after a password change because that operation revokes the
  /// current token before the client can attempt a regular remote sign-out.
  void endSessionAfterPasswordChange() {
    localSignOut();
  }

  void localSignOut() {
    unawaited(_clearStoredSession());
    _setUnauthenticated();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await ref.read(sessionStorageProvider).read();
      if (session == null) {
        _setUnauthenticated();
        return;
      }
      if (session.isExpired || !session.user.isActive) {
        await _clearStoredSession();
        _setUnauthenticated();
        return;
      }

      await ref
          .read(fastifyAuthDataSourceProvider)
          .validateSession(sessionToken: session.sessionToken);
      await _activateAuthenticatedSession(session);
    } on Failure catch (error) {
      if (error.type == FailureType.sessionExpired) {
        await _clearStoredSession();
      }
      _setUnauthenticated();
      if (kDebugMode) {
        debugPrint('session-restore failed: $error');
      }
    } catch (error) {
      await _clearStoredSession();
      _setUnauthenticated();
      if (kDebugMode) {
        debugPrint('session-restore failed: $error');
      }
    }
  }

  Future<void> _activateAuthenticatedSession(AuthSession session) async {
    state = SessionState.authenticated(session);
    await _runBootstrapTask(
      () => ref.read(currentUserViewsProvider.notifier).refresh(),
    );
    await _runBootstrapTask(
      () => ref.read(notificationsProvider.notifier).load(),
    );
    await _runBootstrapTask(
      () => ref
          .read(pushNotificationServiceProvider)
          .activate(session.sessionToken),
    );
    ref.read(postLoginBootstrapProvider.notifier).state = true;
  }

  Future<void> _runBootstrapTask(Future<void> Function() task) async {
    try {
      await task();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('session-bootstrap task failed: $error');
      }
    }
  }

  Future<void> _clearStoredSession() async {
    try {
      await ref.read(sessionStorageProvider).clear();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('session-storage clear failed: $error');
      }
    }
  }

  Future<void> _persistUpdatedSession(AuthSession session) async {
    try {
      await ref.read(sessionStorageProvider).write(session);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('session-storage update failed: $error');
      }
    }
  }

  void _setUnauthenticated() {
    ref.read(postLoginBootstrapProvider.notifier).state = false;
    state = const SessionState.unauthenticated();
  }
}
