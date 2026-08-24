import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/environment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../dashboard/app_shell.dart';
import '../../role_views/app_view_code.dart';
import '../../role_views/providers/current_user_views_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final userViews = ref.watch(currentUserViewsProvider);

    return AppShell(
      title: 'Configuración',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SettingsHeader(),
                const SizedBox(height: 16),
                const _SectionTitle('Apariencia'),
                const _SettingsItem(
                  icon: Icons.palette_outlined,
                  title: 'Apariencia',
                  description: 'Usa la configuración actual de la aplicación.',
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Seguridad'),
                _SettingsItem(
                  icon: Icons.lock_outline,
                  title: 'Cambio de contraseña',
                  description: 'Actualiza la contraseña de tu cuenta.',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/profile/change-password'),
                ),
                if (userViews.canView(AppViewCode.roleViewsManagement)) ...[
                  const SizedBox(height: 12),
                  _SettingsItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Roles y vistas',
                    description: 'Configura los módulos disponibles para cada rol.',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/role-views'),
                  ),
                ],
                if (userViews.canView(AppViewCode.orders)) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Pedidos'),
                  _SettingsItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Tipos de pedido',
                    description: 'Crea, edita y activa los tipos de pedido.',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/orders/descriptions'),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionTitle('Notificaciones'),
                const _SettingsItem(
                  icon: Icons.notifications_none,
                  title: 'Notificaciones',
                  description: 'Próximamente',
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Seguimiento'),
                const _SettingsItem(
                  icon: Icons.location_searching_outlined,
                  title: 'Seguimiento de pedidos',
                  description: 'Próximamente',
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Acerca de'),
                _SettingsItem(
                  icon: Icons.info_outline,
                  title: 'Fleet Control',
                  description: 'Versión: ${AppConstants.version}',
                  details: kDebugMode
                      ? 'Development (${config.environment.name})'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.settings_outlined, size: 42, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Configuración',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Preferencias y opciones de Fleet Control.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.description,
    this.details,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? details;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: details == null
            ? Text(description)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(description), Text(details!)],
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
