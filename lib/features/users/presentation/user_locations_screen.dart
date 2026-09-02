import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/role_label.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/user_dto.dart';
import '../data/dtos/user_location_option_dto.dart';
import '../providers/user_locations_provider.dart';

class UserLocationsScreen extends ConsumerStatefulWidget {
  const UserLocationsScreen({super.key, required this.user});

  final UserDto user;

  @override
  ConsumerState<UserLocationsScreen> createState() =>
      _UserLocationsScreenState();
}

class _UserLocationsScreenState extends ConsumerState<UserLocationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        debugPrint('opening user locations userId=${widget.user.id}');
      }
      ref.read(userLocationsProvider.notifier).load(widget.user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userLocationsProvider);

    return AppShell(
      title: 'Locales asignados',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UserSummary(user: widget.user),
                const SizedBox(height: 16),
                if (!state.isLoading &&
                    state.errorMessage == null &&
                    state.locations.isNotEmpty &&
                    state.selectedLocationIds.isEmpty) ...[
                  const _NoAssignedLocations(),
                  const SizedBox(height: 16),
                ],
                if (state.errorMessage != null) ...[
                  _ErrorMessage(message: state.errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (widget.user.companyId == null)
                  const _UserWithoutCompany()
                else if (state.locations.isEmpty)
                  const _EmptyLocations()
                else ...[
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: state.isSaving
                            ? null
                            : ref
                                  .read(userLocationsProvider.notifier)
                                  .selectAll,
                        icon: const Icon(Icons.select_all),
                        label: const Text('SELECCIONAR TODOS'),
                      ),
                      TextButton.icon(
                        onPressed: state.isSaving
                            ? null
                            : ref.read(userLocationsProvider.notifier).clearAll,
                        icon: const Icon(Icons.deselect),
                        label: const Text('DESELECCIONAR TODOS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...state.locations.map(
                    (location) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LocationOption(
                        location: location,
                        selected: state.selectedLocationIds.contains(
                          location.id,
                        ),
                        enabled:
                            !state.isSaving &&
                            (location.isActive ||
                                state.selectedLocationIds.contains(
                                  location.id,
                                )),
                        onChanged: (selected) => ref
                            .read(userLocationsProvider.notifier)
                            .toggle(location.id, selected),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: state.isSaving
                          ? null
                          : () => context.pop(false),
                      child: const Text('CANCELAR'),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          state.isLoading ||
                              state.isSaving ||
                              widget.user.companyId == null
                          ? null
                          : _save,
                      icon: state.isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('GUARDAR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final saved = await ref
        .read(userLocationsProvider.notifier)
        .save(widget.user.id);
    if (!saved || !mounted) return;
    context.pop(true);
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user});

  final UserDto user;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Locales asignados de ${user.nombre}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('Usuario: ${user.usuario}'),
          Text('Empresa: ${user.companyName ?? 'Sin empresa asignada'}'),
          Text('Rol: ${roleLabel(user.role ?? '')}'),
        ],
      ),
    ),
  );
}

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.location,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final UserLocationOptionDto location;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: CheckboxListTile(
      value: selected,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      title: Text(location.nombre),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location.direccion != null) Text(location.direccion!),
          if (!location.isActive) const Text('Inactivo'),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}

class _EmptyLocations extends StatelessWidget {
  const _EmptyLocations();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No hay locales disponibles para este usuario.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _NoAssignedLocations extends StatelessWidget {
  const _NoAssignedLocations();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Este usuario no tiene locales asignados.'),
    ),
  );
}

class _UserWithoutCompany extends StatelessWidget {
  const _UserWithoutCompany();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Primero asigna una empresa al usuario. Los locales disponibles pertenecen a su empresa.',
        textAlign: TextAlign.center,
      ),
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
