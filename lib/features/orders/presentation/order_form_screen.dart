import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/providers/session_provider.dart';
import '../../locations/presentation/widgets/location_map_preview.dart';
import '../data/dtos/order_dto.dart';
import '../providers/orders_provider.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});
  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _invoice = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  String? _locationId, _descriptionId, _priority = 'normal';
  String? _loadedDescriptionCompanyId;
  double? _lat, _lng;

  bool get _canManageDescriptions {
    final role = ref.read(sessionProvider).session?.user.role;
    return role == 'admin' || role == 'super_admin';
  }

  @override
  void dispose() {
    for (final controller in [_destination, _invoice, _contact, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final isLocal = ref.watch(sessionProvider).session?.user.role == 'local';
    if (state.locations.isEmpty) return _noLocations();
    final location = state.locations.firstWhere(
      (item) => item.id == _locationId,
      orElse: () => state.locations.first,
    );
    if (_locationId == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _locationId = location.id),
      );
    }
    if (_loadedDescriptionCompanyId != location.empresaId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref
            .read(ordersProvider.notifier)
            .loadDescriptions(location.empresaId),
      );
      _loadedDescriptionCompanyId = location.empresaId;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo pedido'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Nuevo pedido',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Completa los datos para solicitar una gestión.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Local y descripción',
                  child: Column(
                    children: [
                      if (isLocal && state.locations.length == 1)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(location.nombre),
                          subtitle: const Text('Local asignado'),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _locationId ?? location.id,
                          decoration: const InputDecoration(labelText: 'Local *'),
                          items: state.locations
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.nombre),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final selected = state.locations.firstWhere(
                              (item) => item.id == value,
                            );
                            setState(() {
                              _locationId = value;
                              _descriptionId = null;
                              _loadedDescriptionCompanyId = selected.empresaId;
                            });
                            ref
                                .read(ordersProvider.notifier)
                                .loadDescriptions(selected.empresaId);
                          },
                        ),
                      const SizedBox(height: 16),
                      if (state.descriptions.isEmpty)
                        _NoDescriptions(
                          canManage: _canManageDescriptions,
                          onConfigure: () =>
                              _configureDescriptions(location.empresaId),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _descriptionId,
                          decoration: const InputDecoration(
                            labelText: 'Descripción *',
                          ),
                          items: state.descriptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _descriptionId = value),
                          validator: (value) => value == null
                              ? 'Selecciona una descripción.'
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Destino',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _destination,
                        decoration: const InputDecoration(
                          labelText: 'Destino / Dirección',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ubicación de destino',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LocationMapPreview(
                        latitude: _lat,
                        longitude: _lng,
                        radiusMeters: null,
                        onPointSelected: (point) => setState(() {
                          _lat = point.latitude;
                          _lng = point.longitude;
                        }),
                      ),
                      if (_lat != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Coordenadas: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Datos del pedido',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _invoice,
                        decoration: const InputDecoration(
                          labelText: 'Factura o Solicitud',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contact,
                        decoration: const InputDecoration(
                          labelText: 'Número de contacto',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Prioridad y observaciones',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'baja', child: Text('Baja')),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: 'urgente',
                            child: Text('Urgente'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: state.creating || state.descriptions.isEmpty
                      ? null
                      : _submit,
                  child: Text(state.creating ? 'SOLICITANDO...' : 'SOLICITAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noLocations() => Scaffold(
    appBar: AppBar(title: const Text('Nuevo pedido')),
    body: const Center(
      child: Text('No tienes locales asignados para crear pedidos.'),
    ),
  );

  Future<void> _configureDescriptions(String companyId) async {
    await context.push('/orders/descriptions', extra: companyId);
    if (mounted) {
      await ref.read(ordersProvider.notifier).loadDescriptions(companyId);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() ||
        _locationId == null ||
        _descriptionId == null) {
      return;
    }
    final created = await ref
        .read(ordersProvider.notifier)
        .create(
          CreateOrderRequest(
            locationId: _locationId!,
            descriptionId: _descriptionId!,
            priority: _priority!,
            destination: _destination.text.trim().isEmpty
                ? null
                : _destination.text.trim(),
            latitude: _lat,
            longitude: _lng,
            invoiceRequest: _invoice.text.trim().isEmpty
                ? null
                : _invoice.text.trim(),
            contactNumber: _contact.text.trim().isEmpty
                ? null
                : _contact.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
        );
    if (created && mounted) context.pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _NoDescriptions extends StatelessWidget {
  const _NoDescriptions({required this.canManage, required this.onConfigure});
  final bool canManage;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No hay tipos de pedido configurados para esta empresa.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (canManage)
            FilledButton.tonal(
              onPressed: onConfigure,
              child: const Text('CONFIGURAR TIPOS DE PEDIDO'),
            )
          else
            const Text(
              'Solicita a un administrador que configure al menos un tipo de pedido.',
            ),
        ],
      ),
    ),
  );
}
