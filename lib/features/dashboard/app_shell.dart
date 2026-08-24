import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../authentication/providers/session_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    this.title = 'Fleet Control',
    this.showHomeAction = false,
  });

  final Widget child;
  final String title;
  final bool showHomeAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(sessionProvider).session?.user.displayName ??
        'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showHomeAction)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Ir al inicio',
              onPressed: () => context.go('/home'),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    '👤 $userName',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: child,
    );
  }
}
