import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/role_label.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/role_views_dto.dart';
import '../providers/role_views_management_provider.dart';

class RoleViewsScreen extends ConsumerStatefulWidget {
  const RoleViewsScreen({super.key});

  @override
  ConsumerState<RoleViewsScreen> createState() => _RoleViewsScreenState();
}

class _RoleViewsScreenState extends ConsumerState<RoleViewsScreen> {
  String? _selectedRoleCode;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(roleViewsManagementProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleViewsManagementProvider);
    final selectedRole = _selectedRoleCode ??
        (state.roles.isEmpty ? null : state.roles.first.code);

    return AppShell(
      title: 'Roles y vistas',
      showHomeAction: true,
      child: state.isLoading && state.roles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Roles y vistas',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Define qué módulos pueden verse y abrirse para cada rol. Los cambios se guardan inmediatamente.',
                      ),
                      const SizedBox(height: 24),
                      if (state.errorMessage != null)
                        _ErrorCard(
                          message: state.errorMessage!,
                          onRetry: () => ref
                              .read(roleViewsManagementProvider.notifier)
                              .load(),
                        ),
                      if (state.errorMessage != null) const SizedBox(height: 16),
                      if (state.roles.isEmpty && state.errorMessage == null)
                        const _EmptyState()
                      else if (selectedRole != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.roles
                              .map(
                                (role) => ChoiceChip(
                                  label: Text(roleLabel(role.code)),
                                  selected: role.code == selectedRole,
                                  onSelected: (_) => setState(
                                    () => _selectedRoleCode = role.code,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          roleLabel(selectedRole),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...state.views
                            .where((view) => view.isActive)
                            .map(
                              (view) => _ViewSwitch(
                                roleCode: selectedRole,
                                view: view,
                                visible: state.isVisible(
                                  selectedRole,
                                  view.code,
                                ),
                                saving: state.isSaving(selectedRole, view.code),
                                onChanged: (visible) => _updateView(
                                  roleCode: selectedRole,
                                  view: view,
                                  visible: visible,
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _updateView({
    required String roleCode,
    required AppViewDto view,
    required bool visible,
  }) async {
    final message = await ref.read(roleViewsManagementProvider.notifier).update(
          roleCode: roleCode,
          viewCode: view.code,
          visible: visible,
        );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.roleCode,
    required this.view,
    required this.visible,
    required this.saving,
    required this.onChanged,
  });

  final String roleCode;
  final AppViewDto view;
  final bool visible;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: SwitchListTile.adaptive(
      value: visible,
      onChanged: saving ? null : onChanged,
      title: Text(view.name),
      subtitle: Text(view.description ?? view.code),
      secondary: saving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No hay roles configurables disponibles.'),
    ),
  );
}
