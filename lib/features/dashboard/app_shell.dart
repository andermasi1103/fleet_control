import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../authentication/providers/session_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String usuario;

  const AppShell({super.key, required this.child, required this.usuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Control"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text("👤 $usuario"),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: "Cerrar sesión",
                  onPressed: () {
                    // 🔹 Limpiar sesión
                    ref.read(sessionProvider.notifier).clearSession();
                    // 🔹 Redirigir al login
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text("Menú")),
            const ListTile(title: Text("Dashboard")),
            const ListTile(title: Text("Usuarios")),
            const ListTile(title: Text("Choferes")),
            const ListTile(title: Text("Asistencia")),
            const ListTile(title: Text("Flota")),
            const ListTile(title: Text("Ubicación")),
            const ListTile(title: Text("Reportes")),
            ListTile(
              title: const Text("Cerrar sesión"),
              leading: const Icon(Icons.logout),
              onTap: () {
                ref.read(sessionProvider.notifier).clearSession();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
