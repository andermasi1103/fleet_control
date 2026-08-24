import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_loading.dart';
import '../../authentication/providers/session_provider.dart';
import '../../managements/data/dtos/management_dto.dart';
import '../../managements/providers/managements_provider.dart';
import '../data/dtos/order_dto.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ordersProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Inicio',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.locations.isEmpty
            ? null
            : () => context.push('/orders/new'),
        label: const Text('NUEVO PEDIDO'),
        icon: const Icon(Icons.add),
      ),
      body: state.loading
          ? const AppLoading()
          : Column(
              children: [
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: state.orders.isEmpty
                      ? const Center(
                          child: Text('No hay pedidos para mostrar.'),
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(ordersProvider.notifier).load(),
                          child: ListView.builder(
                            itemCount: state.orders.length,
                            itemBuilder: (context, index) {
                              final order = state.orders[index];
                              return Card(
                                child: ListTile(
                                  onTap: () =>
                                      context.push('/orders/${order.id}'),
                                  title: Text(order.locationName ?? 'Local'),
                                  subtitle: Text(
                                    '${order.description ?? 'Sin descripción'}\n${order.destination ?? 'Sin destino'}\nPrioridad: ${_priority(order.priority)} · ${_status(order.status)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

String _priority(String value) => switch (value) {
  'baja' => 'Baja',
  'urgente' => 'Urgente',
  _ => 'Normal',
};
String _status(String value) => switch (value) {
  'pendiente' => 'Pendiente',
  'asignado' => 'Asignado',
  'aceptado' => 'Aceptado',
  'en_camino' => 'En camino',
  'en_gestion' => 'En gestión',
  'completado' => 'Completado',
  'cancelado' => 'Cancelado',
  _ => value,
};

enum _OrderDetailLookup { loading, loaded, notFound, error }

enum _ManagementLookup { loading, found, notFound, error }

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  var _orderLookup = _OrderDetailLookup.loading;
  OrderDto? _order;
  var _managementLookup = _ManagementLookup.loading;
  ManagementDto? _management;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadOrder);
  }

  Future<void> _loadOrder() async {
    if (mounted) {
      setState(() {
        _orderLookup = _OrderDetailLookup.loading;
        _order = null;
      });
    }

    try {
      final order = await ref
          .read(ordersProvider.notifier)
          .detail(widget.orderId);
      if (!mounted) return;

      if (order == null) {
        setState(() => _orderLookup = _OrderDetailLookup.notFound);
        return;
      }

      setState(() {
        _order = order;
        _orderLookup = _OrderDetailLookup.loaded;
      });
      if (ref.read(sessionProvider).session?.user.role == 'local') {
        setState(() => _managementLookup = _ManagementLookup.notFound);
      } else {
        await _findManagement();
      }
    } catch (_) {
      if (mounted) setState(() => _orderLookup = _OrderDetailLookup.error);
    }
  }

  Future<void> _findManagement() async {
    final order = _order;
    if (order == null) return;

    setState(() {
      _managementLookup = _ManagementLookup.loading;
      _management = null;
    });

    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired) {
      if (mounted) setState(() => _managementLookup = _ManagementLookup.error);
      return;
    }

    try {
      final managements = await ref
          .read(managementsSourceProvider)
          .list(session.sessionToken, orderId: order.id);
      if (!mounted) return;

      setState(() {
        _management = managements.isEmpty ? null : managements.first;
        _managementLookup = managements.isEmpty
            ? _ManagementLookup.notFound
            : _ManagementLookup.found;
      });
    } catch (_) {
      if (mounted) setState(() => _managementLookup = _ManagementLookup.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (_orderLookup == _OrderDetailLookup.loading) {
      return _detailScaffold(
        context,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_orderLookup == _OrderDetailLookup.notFound) {
      return _detailScaffold(
        context,
        body: const Center(child: Text('El pedido ya no está disponible.')),
      );
    }
    if (_orderLookup == _OrderDetailLookup.error || order == null) {
      return _detailScaffold(
        context,
        body: Center(
          child: TextButton(
            onPressed: _loadOrder,
            child: const Text('REINTENTAR CARGA DEL PEDIDO'),
          ),
        ),
      );
    }

    final role = ref.watch(sessionProvider).session?.user.role;
    final canAssign =
        order.status == 'pendiente' &&
        const {'super_admin', 'admin', 'supervisor'}.contains(role);
    final canCancel = role == 'local'
        ? order.status == 'pendiente'
        : ['pendiente', 'asignado'].contains(order.status);

    return Scaffold(
      appBar: _appBar(context),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _line('Local', order.locationName),
          _line('Descripción', order.description),
          _line('Destino', order.destination),
          _line('Factura / Solicitud', order.invoiceRequest),
          _line('Contacto', order.contactNumber),
          _line('Prioridad', _priority(order.priority)),
          _line('Estado', _status(order.status)),
          _line('Observaciones', order.notes),
          _line('Creado por', order.createdByName),
          _line('Fecha/hora', order.createdAt.toLocal().toString()),
          if (order.latitude != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Ubicación disponible en el pedido.'),
            ),
          if (_managementLookup == _ManagementLookup.loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_managementLookup == _ManagementLookup.found)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton(
                onPressed: () =>
                    context.push('/managements/${_management!.id}'),
                child: const Text('VER GESTIÓN'),
              ),
            )
          else if (_managementLookup == _ManagementLookup.notFound && canAssign)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton(
                onPressed: () async {
                  await context.push(
                    '/orders/${order.id}/assign-management',
                    extra: order,
                  );
                  if (mounted) await _findManagement();
                },
                child: const Text('ASIGNAR GESTIÓN'),
              ),
            )
          else if (_managementLookup == _ManagementLookup.error)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No fue posible verificar si el pedido tiene una gestión.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _findManagement,
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          if (canCancel)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton.tonal(
                onPressed: () => _cancel(context),
                child: const Text('CANCELAR PEDIDO'),
              ),
            ),
        ],
      ),
    );
  }

  Scaffold _detailScaffold(BuildContext context, {required Widget body}) =>
      Scaffold(appBar: _appBar(context), body: body);

  AppBar _appBar(BuildContext context) => AppBar(
    title: const Text('Detalle del pedido'),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Volver',
      onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
    ),
  );

  Widget _line(String label, String? value) => value == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('$label: $value'),
        );

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('¿Deseas cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('NO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        await ref.read(ordersProvider.notifier).cancel(_order!.id) &&
        context.mounted) {
      context.pop();
    }
  }
}
