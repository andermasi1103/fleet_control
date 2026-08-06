import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class FleetControlApp extends StatelessWidget {
  const FleetControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fleet Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}