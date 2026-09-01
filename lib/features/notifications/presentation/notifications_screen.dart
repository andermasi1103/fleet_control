import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/dtos/notification_dto.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: state.loading
                ? null
                : () => ref.read(notificationsProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Inicio',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: state.loading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(notificationsProvider.notifier).load(),
              child: state.notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No tienes notificaciones.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.notifications.length,
                      itemBuilder: (context, index) => _NotificationTile(
                        notification: state.notifications[index],
                        onTap: () async {
                          final notification = state.notifications[index];
                          await ref
                              .read(notificationsProvider.notifier)
                              .markRead(notification);
                          if (!context.mounted) return;
                          if (notification.route == '/driver-orders') {
                            context.push('/driver-orders');
                          }
                        },
                      ),
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final NotificationDto notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: notification.isRead
        ? null
        : Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      leading: Icon(
        notification.isRead ? Icons.notifications_none : Icons.notifications,
      ),
      title: Text(notification.title),
      subtitle: Text(
        '${notification.message}\n${_dateLabel(notification.createdAt.toLocal())}',
      ),
      isThreeLine: true,
      onTap: onTap,
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
