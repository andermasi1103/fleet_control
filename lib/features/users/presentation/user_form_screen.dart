import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/role_label.dart';
import '../../dashboard/app_shell.dart';
import '../../user_vehicles/data/dtos/user_vehicle_dto.dart';
import '../data/dtos/user_dto.dart';
import '../providers/users_provider.dart';
import '../providers/users_state.dart';
import '../../user_vehicles/providers/user_vehicles_provider.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.initialUser});

  final UserDto? initialUser;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _companyId;
  String? _roleId;
  late bool _isActive;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  bool _isSubmitting = false;
  bool _hasRequestedHabitualVehicle = false;

  bool get _isEditing => widget.initialUser != null;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    _nameController = TextEditingController(text: user?.nombre ?? '');
    _usernameController = TextEditingController(text: user?.usuario ?? '');
    _companyId = user?.companyId;
    _roleId = user?.roleId;
    _isActive = user?.isActive ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(usersProvider);
      if (state.users.isEmpty || state.companies.isEmpty) {
        ref.read(usersProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final roles = state.roles;
    String? selectedRoleCode;
    for (final role in roles) {
      if (role.id == _roleId) {
        selectedRoleCode = role.code;
        break;
      }
    }
    final isDriver =
        _isEditing &&
        (selectedRoleCode ?? widget.initialUser?.role) == 'chofer';
    if (isDriver && !_hasRequestedHabitualVehicle) {
      _hasRequestedHabitualVehicle = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(userVehicleProvider.notifier).load(widget.initialUser!.id);
        }
      });
    }
    final userVehicleState = ref.watch(userVehicleProvider);
    _selectOnlyOption(state.companies.length, roles.length, state);

    return AppShell(
      title: _isEditing ? 'Editar usuario' : 'Nuevo usuario',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEditing ? 'Editar usuario' : 'Registrar nuevo usuario',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    _ErrorMessage(message: state.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  if (roles.isEmpty) ...[
                    const _ErrorMessage(
                      message: 'No hay roles disponibles para crear usuarios.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _companyId ?? '',
                    decoration: const InputDecoration(labelText: 'Empresa'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Sin empresa asignada'),
                      ),
                      ...state.companies.map(
                        (company) => DropdownMenuItem(
                          value: company.id,
                          child: Text(company.nombre),
                        ),
                      ),
                    ],
                    onChanged: state.isSaving
                        ? null
                        : (value) => setState(
                            () => _companyId = value == null || value.isEmpty
                                ? null
                                : value,
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: !state.isSaving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    validator: _nameValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(labelText: 'Usuario *'),
                    validator: _usernameValidator,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _roleId,
                    decoration: const InputDecoration(labelText: 'Rol *'),
                    items: roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role.id,
                            child: Text(role.name ?? roleLabel(role.code)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: state.isSaving || roles.isEmpty
                        ? null
                        : (value) => setState(() => _roleId = value),
                    validator: (value) => value == null || !_isUuid(value)
                        ? 'Selecciona un rol.'
                        : null,
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !state.isSaving,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: state.isSaving
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePasswordConfirmation,
                      enabled: !state.isSaving,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña *',
                        suffixIcon: IconButton(
                          tooltip: _obscurePasswordConfirmation
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscurePasswordConfirmation
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: state.isSaving
                              ? null
                              : () => setState(
                                  () => _obscurePasswordConfirmation =
                                      !_obscurePasswordConfirmation,
                                ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: _confirmPasswordValidator,
                    ),
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usuario activo'),
                      value: _isActive,
                      onChanged: state.isSaving
                          ? null
                          : (value) => setState(() => _isActive = value),
                    ),
                  ],
                  if (isDriver) ...[
                    const SizedBox(height: 24),
                    _HabitualVehicleSection(
                      state: userVehicleState,
                      onRetry: () => ref
                          .read(userVehicleProvider.notifier)
                          .load(widget.initialUser!.id),
                      onAssign: () => _selectHabitualVehicle(
                        userVehicleState.vehicles,
                        userVehicleState.assignment?.vehicleId,
                      ),
                      onClear: userVehicleState.isSaving
                          ? null
                          : () => _updateHabitualVehicle(null),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: state.isSaving ? null : () => context.pop(),
                        child: const Text('CANCELAR'),
                      ),
                      ElevatedButton(
                        onPressed:
                            state.isSaving || _isSubmitting || roles.isEmpty
                            ? null
                            : _save,
                        child: Text(
                          state.isSaving ? 'GUARDANDO...' : 'GUARDAR',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectOnlyOption(int companyCount, int roleCount, UsersState state) {
    if (_isEditing || state.isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = ref.read(usersProvider);
      if (_companyId == null && companyCount == 1) {
        setState(() => _companyId = latest.companies.single.id);
      }
      if (_roleId == null && roleCount == 1) {
        setState(() => _roleId = latest.roles.single.id);
      }
    });
  }

  Future<void> _save() async {
    if (_isSubmitting ||
        !_formKey.currentState!.validate() ||
        _roleId == null ||
        !_isUuid(_roleId!)) {
      return;
    }
    setState(() => _isSubmitting = true);
    final notifier = ref.read(usersProvider.notifier);
    final success = _isEditing
        ? await notifier.updateUser(
            id: widget.initialUser!.id,
            nombre: _nameController.text.trim(),
            usuario: _usernameController.text.trim(),
            companyId: _companyId,
            roleId: _roleId!,
            isActive: _isActive,
          )
        : await notifier.createUser(
            nombre: _nameController.text.trim(),
            usuario: _usernameController.text.trim(),
            password: _passwordController.text,
            companyId: _companyId,
            roleId: _roleId!,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      _passwordController.clear();
      _confirmPasswordController.clear();
      context.pop(true);
      return;
    }
    final message =
        ref.read(usersProvider).errorMessage ??
        'No fue posible completar la operación.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _selectHabitualVehicle(
    List<UserVehicleOptionDto> vehicles,
    String? currentVehicleId,
  ) async {
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay vehículos activos para esta empresa.'),
        ),
      );
      return;
    }
    var selectedVehicleId = currentVehicleId ?? vehicles.first.id;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vehículo habitual'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedVehicleId,
            decoration: const InputDecoration(labelText: 'Vehículo'),
            items: vehicles
                .map(
                  (vehicle) => DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(vehicle.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setDialogState(
              () => selectedVehicleId = value ?? selectedVehicleId,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedVehicleId),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _updateHabitualVehicle(selected);
  }

  Future<void> _updateHabitualVehicle(String? vehicleId) async {
    final success = await ref
        .read(userVehicleProvider.notifier)
        .update(widget.initialUser!.id, vehicleId);
    if (!mounted) return;
    final message = success
        ? vehicleId == null
              ? 'Vehículo habitual eliminado.'
              : 'Vehículo habitual actualizado.'
        : ref.read(userVehicleProvider).errorMessage ??
              'No fue posible actualizar el vehículo habitual.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  String? _nameValidator(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty || name.length > 160) {
      return 'Ingresa un nombre válido de hasta 160 caracteres.';
    }
    return null;
  }

  String? _usernameValidator(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty || username.length > 100) {
      return 'Ingresa un usuario válido de hasta 100 caracteres.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (password.length > 1024) {
      return 'La contraseña no puede superar 1024 caracteres.';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final confirmation = value ?? '';
    if (confirmation.isEmpty) return 'Confirma la contraseña.';
    if (confirmation != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}

class _HabitualVehicleSection extends StatelessWidget {
  const _HabitualVehicleSection({
    required this.state,
    required this.onRetry,
    required this.onAssign,
    required this.onClear,
  });

  final UserVehicleState state;
  final VoidCallback onRetry;
  final VoidCallback onAssign;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final vehicle = state.assignment?.vehicle;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VEHÍCULO HABITUAL',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.errorMessage != null) ...[
              Text(state.errorMessage!),
              TextButton(onPressed: onRetry, child: const Text('REINTENTAR')),
            ] else ...[
              Text(
                vehicle == null
                    ? 'Sin vehículo habitual asignado.'
                    : vehicle.label,
              ),
              if (vehicle?.vehicleType != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Tipo: ${vehicle!.vehicleType}'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: state.isSaving ? null : onAssign,
                    child: Text(vehicle == null ? 'ASIGNAR' : 'CAMBIAR'),
                  ),
                  if (vehicle != null)
                    OutlinedButton(
                      onPressed: onClear,
                      child: const Text('QUITAR'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
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
