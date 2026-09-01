import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/dtos/available_order_dto.dart';
import '../providers/driver_orders_provider.dart';

class DriverOrdersScreen extends ConsumerStatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  ConsumerState<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends ConsumerState<DriverOrdersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(driverOrdersProvider.notifier).load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.read(driverOrdersProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _claim(AvailableOrderDto order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('¿Quieres tomar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('TOMAR PEDIDO'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final management = await ref
        .read(driverOrdersProvider.notifier)
        .claim(order.id);
    if (!mounted) return;

    if (management != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              management.queuePosition != null && management.queuePosition! > 1
                  ? 'Pedido agregado a tu cola.'
                  : 'Pedido asignado correctamente.',
            ),
          ),
        );
      context.push('/managements/${management.id}');
      return;
    }

    final state = ref.read(driverOrdersProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(state.error ?? 'No fue posible tomar el pedido.'),
        ),
      );
    if (state.errorCode == 'order_already_taken') {
      await ref.read(driverOrdersProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos disponibles'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: state.loading
                ? null
                : () => ref.read(driverOrdersProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Inicio',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: state.loading && state.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(driverOrdersProvider.notifier).load(),
              child: state.orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No hay pedidos disponibles.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.orders.length,
                      itemBuilder: (context, index) => _OrderCard(
                        order: state.orders[index],
                        claiming: state.claiming,
                        onClaim: () => _claim(state.orders[index]),
                      ),
                    ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.claiming,
    required this.onClaim,
  });

  final AvailableOrderDto order;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = order.latitude != null && order.longitude != null;
    final createdAt = order.createdAt.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.description ?? 'Sin descripción',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Local: ${order.locationName ?? 'Sin local'}'),
            Text('Destino: ${order.destination ?? 'Sin destino'}'),
            Text('Prioridad: ${_priority(order.priority)}'),
            Text('Fecha: ${_dateTimeLabel(createdAt)}'),
            if (order.contactNumber != null)
              Text('Contacto: ${order.contactNumber}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.push('/orders/${order.id}'),
                  child: const Text('VER PEDIDO'),
                ),
                if (hasCoordinates)
                  OutlinedButton(
                    onPressed: () => _showDestination(context, order),
                    child: const Text('VER DESTINO'),
                  ),
                if (hasCoordinates)
                  FilledButton.tonal(
                    onPressed: () => _openMaps(order),
                    child: const Text('IR CON MAPS'),
                  ),
                FilledButton(
                  onPressed: claiming ? null : onClaim,
                  child: const Text('TOMAR PEDIDO'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDestination(
    BuildContext context,
    AvailableOrderDto order,
  ) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Destino'),
      content: SizedBox(
        height: 320,
        width: 500,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(order.latitude!, order.longitude!),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(order.latitude!, order.longitude!),
                  child: const Icon(Icons.location_on, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openMaps(AvailableOrderDto order) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${order.latitude},${order.longitude}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _priority(String value) => switch (value) {
  'baja' => 'Baja',
  'urgente' => 'Urgente',
  _ => 'Normal',
};

String _dateTimeLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
