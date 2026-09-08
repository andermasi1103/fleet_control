import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utils/role_label.dart';
import '../authentication/providers/session_provider.dart';
import '../role_views/app_view_code.dart';
import '../role_views/providers/current_user_views_provider.dart';
import '../tracking/providers/driver_tracking_provider.dart';
import 'app_shell.dart';

class UserDashboard extends ConsumerWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final user = sessionState.session?.user;
    final trackingState = ref.watch(driverTrackingProvider);
    final userViews = ref.watch(currentUserViewsProvider);
    final isLocal = user?.role == 'local';

    if (user == null) {
      return const AppShell(
        child: Center(
          child: Text(
            'No se pudo cargar la información del usuario.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return AppShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${user.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Usuario: ${user.usuario}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Rol: ${roleLabel(user.role.isEmpty ? user.roleId : user.role)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (userViews.isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ] else if (userViews.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ViewsErrorCard(
                message: userViews.errorMessage!,
                onRetry: () =>
                    ref.read(currentUserViewsProvider.notifier).refresh(),
              ),
            ] else ...[
              if (userViews.canView(AppViewCode.driverOrders)) ...[
                const SizedBox(height: 16),
                _DriverLocationStatusCard(state: trackingState),
              ],
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columnCount = width >= 1080
                      ? 4
                      : width >= 720
                      ? 3
                      : 2;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columnCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width < 420 ? 1 : 1.25,
                    children: [
                      if (userViews.canView(AppViewCode.attendance))
                        _DashboardCard(
                          icon: Icons.fingerprint,
                          title: 'Marcar entrada',
                          onTap: () => context.push('/attendance'),
                        ),
                      if (userViews.canView(AppViewCode.attendance))
                        _DashboardCard(
                          icon: Icons.history,
                          title: 'Historial',
                          onTap: () => context.push('/attendance/history'),
                        ),
                      if (userViews.canView(AppViewCode.vehicles))
                        _DashboardCard(
                          icon: Icons.local_shipping_outlined,
                          title: 'Vehículos',
                          onTap: () => context.push('/vehicles'),
                        ),
                      if (isLocal && userViews.canView(AppViewCode.orders))
                        _DashboardCard(
                          icon: Icons.add_circle_outline,
                          title: 'Crear pedido',
                          onTap: () => context.push('/orders/new'),
                        ),
                      if (isLocal && userViews.canView(AppViewCode.orders))
                        _DashboardCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'Mis pedidos',
                          onTap: () => context.push('/orders'),
                        ),
                      if (!isLocal && userViews.canView(AppViewCode.orders))
                        _DashboardCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'Pedidos',
                          onTap: () => context.push('/orders'),
                        ),
                      if (userViews.canView(AppViewCode.driverOrders))
                        _DashboardCard(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Pedidos disponibles',
                          onTap: () => context.push('/driver-orders'),
                        ),
                      _DashboardCard(
                        icon: Icons.notifications_outlined,
                        title: 'Notificaciones',
                        onTap: () => context.push('/notifications'),
                      ),
                      if (userViews.canView(AppViewCode.fleetMap))
                        _DashboardCard(
                          icon: Icons.map_outlined,
                          title: 'Mapa de Flota',
                          onTap: () => context.push('/fleet-map'),
                        ),
                      if (userViews.canView(AppViewCode.managements))
                        _DashboardCard(
                          icon: Icons.assignment_outlined,
                          title: 'Gestiones',
                          onTap: () => context.push('/managements'),
                        ),
                      if (userViews.canView(AppViewCode.users))
                        _DashboardCard(
                          icon: Icons.people_outline,
                          title: 'Usuarios',
                          onTap: () => context.push('/users'),
                        ),
                      if (userViews.canView(AppViewCode.companies))
                        _DashboardCard(
                          icon: Icons.business_outlined,
                          title: 'Empresas',
                          onTap: () => context.push('/companies'),
                        ),
                      if (userViews.canView(AppViewCode.locations))
                        _DashboardCard(
                          icon: Icons.location_on_outlined,
                          title: 'Locales',
                          onTap: () => context.push('/locations'),
                        ),
                      if (userViews.canView(AppViewCode.settings))
                        _DashboardCard(
                          icon: Icons.person_outline,
                          title: 'Perfil',
                          onTap: () => context.push('/profile'),
                        ),
                      if (userViews.canView(AppViewCode.settings))
                        _DashboardCard(
                          icon: Icons.settings_outlined,
                          title: 'Configuración',
                          onTap: () => context.push('/settings'),
                        ),
                      if (userViews.canView(AppViewCode.reports))
                        _DashboardCard(
                          icon: Icons.assessment_outlined,
                          title: 'Reportes',
                          onTap: () => context.push('/reports'),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewsErrorCard extends StatelessWidget {
  const _ViewsErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('REINTENTAR')),
        ],
      ),
    ),
  );
}

class _DriverLocationStatusCard extends ConsumerWidget {
  const _DriverLocationStatusCard({required this.state});

  final DriverTrackingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, title, color) = switch (state.status) {
      DriverTrackingStatus.active => (
        Icons.location_on,
        'Ubicación activa',
        Colors.green,
      ),
      DriverTrackingStatus.starting || DriverTrackingStatus.sending => (
        Icons.location_searching,
        'Enviando ubicación',
        Theme.of(context).colorScheme.primary,
      ),
      DriverTrackingStatus.permissionDenied ||
      DriverTrackingStatus.permissionDeniedForever => (
        Icons.location_off,
        'Ubicación sin permiso',
        Theme.of(context).colorScheme.error,
      ),
      DriverTrackingStatus.notificationsBlocked => (
        Icons.notifications_off_outlined,
        'Notificaciones bloqueadas',
        Theme.of(context).colorScheme.error,
      ),
      DriverTrackingStatus.serviceDisabled || DriverTrackingStatus.idle => (
        Icons.location_disabled,
        'Ubicación desactivada',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      DriverTrackingStatus.error => (
        Icons.error_outline,
        'Error temporal de ubicación',
        Theme.of(context).colorScheme.error,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.message ??
                  (state.isTrackingRequested
                      ? 'MasiTrack informa tu ubicación durante la jornada activa, incluso si la app queda en segundo plano.'
                      : 'Inicia tu jornada para compartir tu ubicación con la operación de flota.'),
            ),
            const SizedBox(height: 12),
            if (state.isTrackingRequested)
              OutlinedButton.icon(
                onPressed: state.status == DriverTrackingStatus.starting
                    ? null
                    : () => ref
                        .read(driverTrackingProvider.notifier)
                        .stopTracking(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('FINALIZAR JORNADA'),
              )
            else
              FilledButton.icon(
                onPressed: state.status == DriverTrackingStatus.starting
                    ? null
                    : () => ref
                        .read(driverTrackingProvider.notifier)
                        .startTracking(),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('INICIAR SEGUIMIENTO'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
