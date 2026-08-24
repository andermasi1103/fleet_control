import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/app_shell.dart';
import '../data/dtos/user_dto.dart';
import '../providers/users_provider.dart';
import 'user_reset_password_dialog.dart';
import 'widgets/user_card.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final users = state.filteredUsers;

    return AppShell(
      title: 'Usuarios',
      showHomeAction: true,
      child: RefreshIndicator(
        onRefresh: () => ref.read(usersProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuarios',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Administra los usuarios, empresas, roles y acceso al sistema.',
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _createUser,
                  icon: const Icon(Icons.add),
                  label: const Text('NUEVO USUARIO'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              enabled: !state.isLoading,
              decoration: const InputDecoration(
                labelText: 'Buscar usuarios',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref.read(usersProvider.notifier).setSearchQuery,
            ),
            const SizedBox(height: 20),
            if (state.errorMessage != null) ...[
              _ErrorMessage(message: state.errorMessage!),
              const SizedBox(height: 16),
            ],
            if (state.isLoading && state.users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.users.isEmpty && state.errorMessage == null)
              const _EmptyUsers()
            else if (users.isEmpty)
              const _NoSearchResults()
            else
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: UserCard(
                    user: user,
                    onEdit: () => _editUser(user),
                    onResetPassword: () =>
                        showUserResetPasswordDialog(context, user),
                    onAssignLocations: () => _assignLocations(user),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser() async {
    final saved = await context.push<bool>('/users/new');
    if (saved == true && mounted) {
      await _reloadAndNotify('Usuario creado correctamente.');
    }
  }

  Future<void> _editUser(UserDto user) async {
    final saved = await context.push<bool>(
      '/users/${user.id}/edit',
      extra: user,
    );
    if (saved == true && mounted) {
      await _reloadAndNotify('Usuario actualizado correctamente.');
    }
  }

  Future<void> _assignLocations(UserDto user) async {
    final saved = await context.push<bool>(
      '/users/${user.id}/locations',
      extra: user,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locales asignados correctamente.')),
      );
    }
  }

  Future<void> _reloadAndNotify(String message) async {
    await ref.read(usersProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 40),
    child: Center(
      child: Text('No hay usuarios registrados.', textAlign: TextAlign.center),
    ),
  );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 40),
    child: Center(
      child: Text('No se encontraron usuarios.', textAlign: TextAlign.center),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}
