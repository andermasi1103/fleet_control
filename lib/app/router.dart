import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Asegúrate de que esta ruta de importación sea exactamente la correcta hacia tu login_screen.dart
import '../features/authentication/screens/login_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}