import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'theme.dart';
import '../features/tracking/providers/driver_tracking_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Fleet Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
