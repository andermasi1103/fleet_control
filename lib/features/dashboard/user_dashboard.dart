import 'package:flutter/material.dart';
import 'app_shell.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      usuario: "Usuario",
      child: Center(
        child: Text(
          "Bienvenido, Usuario\nFleet Control\n\nSin implementar todavía la lógica real.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
