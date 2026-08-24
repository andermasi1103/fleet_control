import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/location_service.dart';
import '../../attendance/data/dtos/location_dto.dart';
import '../../attendance/providers/attendance_provider.dart'
    show locationServiceProvider;
import '../../dashboard/app_shell.dart';
import '../data/dtos/company_option_dto.dart';
import '../providers/locations_provider.dart';
import 'widgets/location_map_preview.dart';

class LocationFormScreen extends ConsumerStatefulWidget {
  const LocationFormScreen({super.key, this.initialLocation});

  final LocationDto? initialLocation;

  @override
  ConsumerState<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends ConsumerState<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  String? _companyId;
  bool _isActive = true;
  String? _locationMessage;

  bool get _isEditing => widget.initialLocation != null;

  @override
  void initState() {
    super.initState();
    final location = widget.initialLocation;
    _nameController = TextEditingController(text: location?.nombre ?? '');
    _addressController = TextEditingController(text: location?.direccion ?? '');
    _latitudeController = TextEditingController(
      text: location?.latitud.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: location?.longitud.toString() ?? '',
    );
    _radiusController = TextEditingController(
      text: location?.radioMetros.toString() ?? '150',
    );
    _companyId = location?.empresaId;
    _isActive = location?.isActive ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(locationsProvider).companies.isEmpty) {
        ref.read(locationsProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationsProvider);
    final companies = state.companies
        .where((company) {
          return company.isActive || company.id == _companyId;
        })
        .toList(growable: false);
    _selectOnlyCompany(companies);
    final latitude = _parseNumber(_latitudeController.text);
    final longitude = _parseNumber(_longitudeController.text);
    final radius = _parseNumber(_radiusController.text);

    return AppShell(
      title: _isEditing ? 'Editar local' : 'Nuevo local',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fields = _FormFields(
                    companies: companies,
                    selectedCompanyId: _companyId,
                    nameController: _nameController,
                    addressController: _addressController,
                    latitudeController: _latitudeController,
                    longitudeController: _longitudeController,
                    radiusController: _radiusController,
                    isActive: _isActive,
                    isSaving: state.isSaving,
                    locationMessage: _locationMessage,
                    onCompanyChanged: (value) =>
                        setState(() => _companyId = value),
                    onCoordinatesChanged: () => setState(() {}),
                    onActiveChanged: (value) =>
                        setState(() => _isActive = value),
                    onUseCurrentLocation: state.isSaving
                        ? null
                        : _useCurrentLocation,
                  );
                  final preview = LocationMapPreview(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: radius != null && radius > 0 ? radius : null,
                    onPointSelected: _setCoordinates,
                  );
                  final actions = _FormActions(
                    isSaving: state.isSaving,
                    canSave: companies.isNotEmpty,
                    onCancel: () => context.pop(),
                    onSave: _save,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing ? 'Editar local' : 'Registrar nuevo local',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      if (state.errorMessage != null) ...[
                        _ErrorMessage(message: state.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      if (companies.isEmpty && !state.isLoading) ...[
                        const _ErrorMessage(
                          message:
                              'No hay empresas disponibles. Crea una empresa antes de registrar un local.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (constraints.maxWidth >= 760)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields),
                            const SizedBox(width: 24),
                            Expanded(child: preview),
                          ],
                        )
                      else ...[
                        fields,
                        const SizedBox(height: 20),
                        preview,
                      ],
                      const SizedBox(height: 24),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locationMessage = 'Obteniendo ubicación...');
    try {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (!mounted) return;
      _setCoordinates(
        LatLng(position.latitude, position.longitude),
        message: 'Ubicación actual aplicada.',
      );
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() => _locationMessage = _locationErrorMessage(error.error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationMessage = 'No fue posible obtener tu ubicación.');
    }
  }

  /// The coordinate text fields are the single source of truth for the form.
  /// Every map interaction updates them, which in turn rebuilds the marker and
  /// geofence preview. This does not persist anything until the user saves.
  void _setCoordinates(LatLng point, {String? message}) {
    setState(() {
      _latitudeController.text = point.latitude.toStringAsFixed(6);
      _longitudeController.text = point.longitude.toStringAsFixed(6);
      _locationMessage = message;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _companyId == null) {
      setState(() => _locationMessage = 'Completa los campos obligatorios.');
      return;
    }
    final latitude = _parseNumber(_latitudeController.text)!;
    final longitude = _parseNumber(_longitudeController.text)!;
    final radius = _parseNumber(_radiusController.text)!;
    final address = _addressController.text.trim();
    final notifier = ref.read(locationsProvider.notifier);
    final success = _isEditing
        ? await notifier.updateLocation(
            id: widget.initialLocation!.id,
            companyId: _companyId!,
            nombre: _nameController.text.trim(),
            direccion: address.isEmpty ? null : address,
            latitude: latitude,
            longitude: longitude,
            radioMeters: radius,
            isActive: _isActive,
          )
        : await notifier.createLocation(
            companyId: _companyId!,
            nombre: _nameController.text.trim(),
            direccion: address.isEmpty ? null : address,
            latitude: latitude,
            longitude: longitude,
            radioMeters: radius,
          );
    if (!mounted) return;
    final state = ref.read(locationsProvider);
    if (success) {
      context.pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.errorMessage ?? 'No fue posible completar la operación.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _selectOnlyCompany(List<CompanyOptionDto> companies) {
    if (_companyId != null || companies.length != 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _companyId == null) {
        setState(() => _companyId = companies.single.id);
      }
    });
  }

  double? _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String _locationErrorMessage(LocationServiceError error) {
    switch (error) {
      case LocationServiceError.disabled:
        return 'Activa los servicios de ubicación.';
      case LocationServiceError.denied:
        return 'Necesitamos acceso a tu ubicación.';
      case LocationServiceError.deniedForever:
        return 'El permiso de ubicación está bloqueado.';
      case LocationServiceError.unavailable:
        return 'No fue posible obtener tu ubicación.';
    }
  }
}

class _FormFields extends StatelessWidget {
  const _FormFields({
    required this.companies,
    required this.selectedCompanyId,
    required this.nameController,
    required this.addressController,
    required this.latitudeController,
    required this.longitudeController,
    required this.radiusController,
    required this.isActive,
    required this.isSaving,
    required this.locationMessage,
    required this.onCompanyChanged,
    required this.onCoordinatesChanged,
    required this.onActiveChanged,
    required this.onUseCurrentLocation,
  });

  final List<CompanyOptionDto> companies;
  final String? selectedCompanyId;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController radiusController;
  final bool isActive;
  final bool isSaving;
  final String? locationMessage;
  final ValueChanged<String?> onCompanyChanged;
  final VoidCallback onCoordinatesChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback? onUseCurrentLocation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(selectedCompanyId),
        initialValue: selectedCompanyId,
        decoration: const InputDecoration(labelText: 'Empresa *'),
        items: companies
            .map(
              (company) => DropdownMenuItem<String>(
                value: company.id,
                child: Text(company.nombre),
              ),
            )
            .toList(growable: false),
        onChanged: isSaving || companies.isEmpty ? null : onCompanyChanged,
        validator: (value) => value == null ? 'Selecciona una empresa.' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Nombre *'),
        textCapitalization: TextCapitalization.words,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Ingresa el nombre del local.'
            : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: addressController,
        decoration: const InputDecoration(labelText: 'Dirección'),
        textCapitalization: TextCapitalization.sentences,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onUseCurrentLocation,
        icon: const Icon(Icons.my_location_outlined),
        label: const Text('USAR MI UBICACIÓN ACTUAL'),
      ),
      if (locationMessage != null) ...[
        const SizedBox(height: 8),
        Text(locationMessage!),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: latitudeController,
        decoration: const InputDecoration(labelText: 'Latitud *'),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
        ],
        onChanged: (_) => onCoordinatesChanged(),
        validator: (value) {
          final latitude = _number(value);
          return latitude == null || latitude < -90 || latitude > 90
              ? 'Ingresa una latitud entre -90 y 90.'
              : null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: longitudeController,
        decoration: const InputDecoration(labelText: 'Longitud *'),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
        ],
        onChanged: (_) => onCoordinatesChanged(),
        validator: (value) {
          final longitude = _number(value);
          return longitude == null || longitude < -180 || longitude > 180
              ? 'Ingresa una longitud entre -180 y 180.'
              : null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: radiusController,
        decoration: const InputDecoration(
          labelText: 'Radio de geocerca (metros) *',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => onCoordinatesChanged(),
        validator: (value) {
          final radius = _number(value);
          return radius == null || radius <= 0
              ? 'Ingresa un radio mayor a cero.'
              : null;
        },
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Activo'),
        value: isActive,
        onChanged: isSaving ? null : onActiveChanged,
      ),
    ],
  );

  static double? _number(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.isSaving,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final bool isSaving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 12,
    runSpacing: 12,
    children: [
      OutlinedButton(
        onPressed: isSaving ? null : onCancel,
        child: const Text('CANCELAR'),
      ),
      ElevatedButton(
        onPressed: isSaving || !canSave ? null : onSave,
        child: Text(isSaving ? 'GUARDANDO...' : 'GUARDAR'),
      ),
    ],
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
