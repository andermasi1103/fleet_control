import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../authentication/providers/session_provider.dart';
import '../notifications/providers/notifications_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    this.title = 'MasiTrack',
    this.showHomeAction = false,
  });

  final Widget child;
  final String title;
  final bool showHomeAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName =
        ref.watch(sessionProvider).session?.user.displayName ?? 'Usuario';
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    final canPop = context.canPop();

    return PopScope(
      canPop: !showHomeAction || canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showHomeAction) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: 'Notificaciones',
              onPressed: () => context.push('/notifications'),
            ),
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
        body: SafeArea(top: false, child: child),
      ),
    );
  }
}
