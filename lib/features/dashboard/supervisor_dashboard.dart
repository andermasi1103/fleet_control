import 'package:flutter/material.dart';

import 'app_shell.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      usuario: 'Supervisor',
      child: Center(
        child: Text(
          'Bienvenido, Supervisor\n\n'
          'Panel de supervisión\n\n'
          '[ Ver choferes ]\n'
          '[ Gestionar usuarios ]\n'
          '[ Ver asistencia ]',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}