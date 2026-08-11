import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/session_provider.dart';
import '../features/authentication/providers/session_state.dart';
import '../features/authentication/widgets/login_card.dart';

import '../features/dashboard/admin_dashboard.dart';
import '../features/dashboard/supervisor_dashboard.dart';
import '../features/dashboard/chofer_dashboard.dart';
import '../features/dashboard/user_dashboard.dart';

String getHomeRoute(SessionState session) {
  if (session.isAdmin) {
    return '/admin';
  }

  if (session.isSupervisor) {
    return '/supervisor';
  }

  if (session.isChofer) {
    return '/chofer';
  }

  return '/home';
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const Scaffold(
            body: Center(
              child: LoginCard(),
            ),
          );
        },
      ),

      GoRoute(
        path: '/admin',
        builder: (context, state) {
          return const AdminDashboard();
        },
      ),

      GoRoute(
        path: '/supervisor',
        builder: (context, state) {
          return const SupervisorDashboard();
        },
      ),

      GoRoute(
        path: '/chofer',
        builder: (context, state) {
          return const ChoferDashboard();
        },
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) {
          return const UserDashboard();
        },
      ),
    ],

    redirect: (context, state) {
      final isAuthenticated = session.isAuthenticated;
      final isLoggingIn = state.uri.path == '/login';

      // Sin sesión:
      // solamente puede acceder al login.
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // Con sesión:
      // si intenta entrar nuevamente al login,
      // lo enviamos a su dashboard.
      if (isAuthenticated && isLoggingIn) {
        return getHomeRoute(session);
      }

      return null;
    },
  );
});