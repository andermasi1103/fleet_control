import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'theme.dart';
import '../features/tracking/providers/driver_tracking_provider.dart';
import '../features/driver_orders/providers/driver_orders_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/authentication/providers/session_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FleetControlApp extends ConsumerStatefulWidget {
  const FleetControlApp({super.key});

  @override
  ConsumerState<FleetControlApp> createState() => _FleetControlAppState();
}

class _FleetControlAppState extends ConsumerState<FleetControlApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(driverTrackingProvider);
    Future.microtask(() => ref.read(pushNotificationServiceProvider).start(
          onForegroundMessage: _handleForegroundMessage,
          onNotificationOpened: _handleNotificationOpened,
        ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(driverTrackingProvider.notifier).handleLifecycleChange(state);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_order') return;
    ref.read(notificationsProvider.notifier).load();
    ref.read(driverOrdersProvider.notifier).load();
    final messenger = _messengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Nuevo pedido disponible'),
          action: SnackBarAction(
            label: 'VER PEDIDOS',
            onPressed: () => ref.read(routerProvider).go('/driver-orders'),
          ),
        ),
      );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    if (message.data['type'] == 'new_order' &&
        ref.read(sessionProvider).isAuthenticated) {
      ref.read(routerProvider).go('/driver-orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Fleet Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
    );
  }
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();
