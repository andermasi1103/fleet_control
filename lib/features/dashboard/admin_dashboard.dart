import 'package:flutter/material.dart';
import 'app_shell.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      usuario: "Administrador",
      child: Center(
        child: Text(
          "Bienvenido, Administrador\nUsuarios: 25\nChoferes: 18\nVehículos: 12\nSupervisores: 4",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
