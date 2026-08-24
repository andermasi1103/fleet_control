import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/providers/session_provider.dart';
import '../data/dtos/order_dto.dart';
import '../providers/orders_provider.dart';

class OrderDescriptionsScreen extends ConsumerStatefulWidget {
  const OrderDescriptionsScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;

  @override
  ConsumerState<OrderDescriptionsScreen> createState() =>
      _OrderDescriptionsScreenState();
}

class _OrderDescriptionsScreenState
    extends ConsumerState<OrderDescriptionsScreen> {
  String? _companyId;

  bool get _canManage {
    final role = ref.read(sessionProvider).session?.user.role;
    return role == 'admin' || role == 'super_admin';
  }

  @override
  void initState() {
    super.initState();
    _companyId = widget.initialCompanyId;
    Future.microtask(() async {
      final notifier = ref.read(ordersProvider.notifier);
      if (ref.read(ordersProvider).locations.isEmpty) await notifier.load();
      _companyId ??= ref.read(ordersProvider).locations.firstOrNull?.empresaId;
      if (_companyId != null) {
        await notifier.loadDescriptions(_companyId!, activeOnly: false);
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final companies = <String, String>{
      for (final location in state.locations)
        location.empresaId: location.empresaNombre ?? location.empresaId,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de pedido'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      floatingActionButton: _canManage && _companyId != null
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('NUEVO TIPO'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (companies.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: _companyId,
                  decoration: const InputDecoration(labelText: 'Empresa'),
                  items: companies.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _companyId = value);
                    ref
                        .read(ordersProvider.notifier)
                        .loadDescriptions(value, activeOnly: false);
                  },
                ),
              const SizedBox(height: 16),
              if (_companyId == null)
                const Text(
                  'Selecciona una empresa para administrar sus tipos de pedido.',
                )
              else if (state.descriptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'No hay tipos de pedido configurados para esta empresa.',
                  ),
                )
              else
                ...state.descriptions.map(
                  (description) => Card(
                    child: ListTile(
                      title: Text(description.name),
                      subtitle: Text(
                        description.isActive ? 'Activo' : 'Inactivo',
                      ),
                      trailing: _canManage
                          ? const Icon(Icons.edit_outlined)
                          : null,
                      onTap: _canManage ? () => _edit(description) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit([OrderDescriptionDto? current]) async {
    final controller = TextEditingController(text: current?.name ?? '');
    var active = current?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(
            current == null ? 'Nuevo tipo de pedido' : 'Editar tipo de pedido',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              if (current != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || _companyId == null) return;
                final notifier = ref.read(ordersProvider.notifier);
                final success = current == null
                    ? await notifier.createDescription(
                        companyId: _companyId!,
                        name: name,
                      )
                    : await notifier.updateDescription(
                        companyId: _companyId!,
                        id: current.id,
                        name: name,
                        isActive: active,
                      );
                if (dialogContext.mounted && success) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) setState(() {});
  }
}
