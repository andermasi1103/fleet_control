import 'package:flutter/material.dart';
import 'app_shell.dart';

class ChoferDashboard extends StatelessWidget {
  const ChoferDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      usuario: "Chofer",
      child: Center(
        child: Text(
          "Bienvenido, Chofer\n\nEstado: Disponible\n\n[ Marcar entrada ]\n[ Mi ubicación ]",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
