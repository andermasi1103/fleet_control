import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'theme.dart';
import '../features/tracking/providers/driver_tracking_provider.dart';
import '../features/tracking/providers/driver_operational_state_provider.dart';
import '../features/tracking/providers/driver_presence_provider.dart';
import '../features/driver_orders/providers/driver_orders_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/authentication/providers/session_provider.dart';
import '../features/authentication/providers/biometric_unlock_provider.dart';
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
    ref.read(driverOperationalStateProvider);
    ref.read(driverTrackingProvider);
    ref.read(driverPresenceProvider);
    Future.microtask(
      () => ref
          .read(pushNotificationServiceProvider)
          .start(
            onForegroundMessage: _handleForegroundMessage,
            onNotificationOpened: _handleNotificationOpened,
          ),
    );
    ref.listen<BiometricUnlockState>(biometricUnlockProvider, (_, next) {
      if (next.offerActivation) _showBiometricActivationOffer();
    });
  }

  Future<void> _showBiometricActivationOffer() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    await showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('¿Activar ingreso con huella?'),
        content: const Text('Podrás desbloquear MasiTrack sin guardar tu contraseña.'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(biometricUnlockProvider.notifier).dismissOffer();
              Navigator.pop(context);
            },
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () async {
              final enabled = await ref.read(biometricUnlockProvider.notifier).enable();
              if (!context.mounted) return;
              if (enabled) Navigator.pop(context);
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    ref.read(biometricUnlockProvider.notifier).dismissOffer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeDriverTracking());
      return;
    }
    unawaited(
      ref.read(driverPresenceProvider.notifier).handleLifecycleChange(state),
    );
    unawaited(
      ref.read(driverTrackingProvider.notifier).handleLifecycleChange(state),
    );
  }

  Future<void> _resumeDriverTracking() async {
    await ref.read(driverOperationalStateProvider.notifier).refresh();
    await ref
        .read(driverTrackingProvider.notifier)
        .handleLifecycleChange(AppLifecycleState.resumed);
    await ref
        .read(driverPresenceProvider.notifier)
        .handleLifecycleChange(AppLifecycleState.resumed);
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
      title: 'MasiTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
    );
  }
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();
