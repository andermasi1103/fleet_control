import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/vehicle_type.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/vehicle_dto.dart';
import '../providers/vehicles_provider.dart';
import '../providers/vehicles_state.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.initialVehicle});
  final VehicleDto? initialVehicle;
  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plate, _brand, _model, _year, _description;
  String? _companyId;
  late String _vehicleType;
  late bool _active;
  bool _submitting = false;
  bool get _editing => widget.initialVehicle != null;
  @override
  void initState() {
    super.initState();
    final vehicle = widget.initialVehicle;
    _plate = TextEditingController(text: vehicle?.plate ?? '');
    _brand = TextEditingController(text: vehicle?.brand ?? '');
    _model = TextEditingController(text: vehicle?.model ?? '');
    _year = TextEditingController(text: vehicle?.year?.toString() ?? '');
    _description = TextEditingController(text: vehicle?.description ?? '');
    _companyId = vehicle?.companyId;
    _vehicleType = vehicle?.vehicleType ?? 'otro';
    _active = vehicle?.isActive ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(vehiclesProvider).companies.isEmpty) {
        ref.read(vehiclesProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiclesProvider);
    _autoSelect(state);
    return AppShell(
      title: _editing ? 'Editar vehículo' : 'Nuevo vehículo',
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
                    _editing ? 'Editar vehículo' : 'Registrar nuevo vehículo',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.companies.isEmpty && !state.isLoading) ...[
                    const Text('No hay empresas disponibles.'),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _companyId,
                    decoration: const InputDecoration(labelText: 'Empresa *'),
                    items: state.companies
                        .map(
                          (company) => DropdownMenuItem(
                            value: company.id,
                            child: Text(company.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSaving
                        ? null
                        : (value) => setState(() => _companyId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una empresa.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plate,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(labelText: 'Patente *'),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      final plate = value?.trim() ?? '';
                      return plate.isEmpty || plate.length > 30
                          ? 'Ingresa una patente válida de hasta 30 caracteres.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brand,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(labelText: 'Marca'),
                    validator: (value) => (value?.trim().length ?? 0) > 80
                        ? 'La marca no puede superar 80 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _model,
                    enabled: !state.isSaving,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                    validator: (value) => (value?.trim().length ?? 0) > 80
                        ? 'El modelo no puede superar 80 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _vehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de vehículo *',
                    ),
                    items: vehicleTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(vehicleTypeLabel(type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: state.isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _vehicleType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _year,
                    enabled: !state.isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Año'),
                    validator: _yearValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    enabled: !state.isSaving,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (value) => (value?.trim().length ?? 0) > 500
                        ? 'La descripción no puede superar 500 caracteres.'
                        : null,
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vehículo activo'),
                      value: _active,
                      onChanged: state.isSaving
                          ? null
                          : (value) => setState(() => _active = value),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: state.isSaving ? null : () => context.pop(),
                        child: const Text('CANCELAR'),
                      ),
                      ElevatedButton(
                        onPressed:
                            state.isSaving ||
                                _submitting ||
                                state.companies.isEmpty
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

  void _autoSelect(VehiclesState state) {
    if (_editing ||
        state.isLoading ||
        _companyId != null ||
        state.companies.length != 1) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(
          () => _companyId = ref.read(vehiclesProvider).companies.single.id,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_submitting ||
        !_formKey.currentState!.validate() ||
        _companyId == null) {
      return;
    }
    setState(() => _submitting = true);
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final year = _year.text.trim().isEmpty
        ? null
        : int.parse(_year.text.trim());
    final success = _editing
        ? await ref
              .read(vehiclesProvider.notifier)
              .updateVehicle(
                id: widget.initialVehicle!.id,
                companyId: _companyId!,
                plate: _plate.text.trim(),
                brand: optional(_brand),
                model: optional(_model),
                vehicleType: _vehicleType,
                year: year,
                description: optional(_description),
                isActive: _active,
              )
        : await ref
              .read(vehiclesProvider.notifier)
              .createVehicle(
                companyId: _companyId!,
                plate: _plate.text.trim(),
                brand: optional(_brand),
                model: optional(_model),
                vehicleType: _vehicleType,
                year: year,
                description: optional(_description),
              );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      context.pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(vehiclesProvider).errorMessage ??
              'No fue posible completar la operación.',
        ),
      ),
    );
  }

  String? _yearValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    return year == null || year < 1900 || year > 2100
        ? 'Ingresa un año entre 1900 y 2100.'
        : null;
  }
}
