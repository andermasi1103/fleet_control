import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/role_label.dart';
import '../../authentication/providers/session_provider.dart';
import '../../companies/providers/companies_provider.dart';
import '../../companies/providers/companies_state.dart';
import '../../dashboard/app_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _requestedCompanyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(sessionProvider).session?.user;
    final companyId = user?.empresaId;
    if (companyId == null || companyId == _requestedCompanyId) return;
    _requestedCompanyId = companyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(companiesProvider.notifier).loadCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).session?.user;
    final companies = ref.watch(companiesProvider);

    return AppShell(
      title: 'Mi perfil',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ProfileHeader(),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: user == null
                        ? const Text(
                            'No se pudo cargar la información del usuario.',
                          )
                        : Column(
                            children: [
                              _ProfileRow(label: 'Nombre', value: user.nombre),
                              _ProfileRow(
                                label: 'Usuario',
                                value: user.usuario,
                              ),
                              _ProfileRow(
                                label: 'Empresa',
                                value: _companyName(
                                  user.empresaId,
                                  user.role.isEmpty ? user.roleId : user.role,
                                  companies,
                                ),
                              ),
                              _ProfileRow(
                                label: 'Rol',
                                value: roleLabel(
                                  user.role.isEmpty ? user.roleId : user.role,
                                ),
                              ),
                              _ProfileRow(
                                label: 'Estado',
                                value: user.isActive ? 'Activo' : 'Inactivo',
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: user == null
                      ? null
                      : () => context.push('/profile/change-password'),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('CAMBIAR CONTRASEÑA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _companyName(
    String? companyId,
    String role,
    CompaniesState companiesState,
  ) {
    if (companyId == null && role == 'super_admin') return 'Acceso global';
    if (companyId == null) return 'Sin empresa asignada';
    if (companiesState.isLoading) return 'Cargando empresa...';
    for (final company in companiesState.companies) {
      if (company.id == companyId) return company.nombre;
    }
    return 'Sin información';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person_outline, size: 42, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Mi perfil', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Consulta tu información y administra tu acceso.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value.isEmpty ? 'Sin información' : value)),
        ],
      ),
    );
  }
}
