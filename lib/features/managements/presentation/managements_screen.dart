import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../authentication/providers/session_provider.dart';
import '../data/dtos/management_dto.dart';
import '../providers/managements_provider.dart';

class ManagementsScreen extends ConsumerStatefulWidget {
  const ManagementsScreen({super.key});
  @override
  ConsumerState<ManagementsScreen> createState() => _S();
}

class _S extends ConsumerState<ManagementsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(managementsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext c) {
    final s = ref.watch(managementsProvider);
    final role = ref.watch(sessionProvider).session?.user.role;
    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'chofer' ? 'Mis gestiones' : 'Gestiones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Inicio',
            onPressed: () => c.go('/home'),
          ),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : role == 'chofer'
          ? _DriverManagementsList(items: s.items)
          : ListView(
              children: s.items
                  .map((m) => _ManagementTile(management: m))
                  .toList(),
            ),
    );
  }
}

class _DriverManagementsList extends StatelessWidget {
  const _DriverManagementsList({required this.items});

  final List<ManagementDto> items;

  @override
  Widget build(BuildContext context) {
    const activeStates = {'aceptado', 'en_camino', 'en_gestion'};
    final active = items
        .where((m) => activeStates.contains(m.managementStatus))
        .toList();
    final queued = items.where((m) => m.managementStatus == 'asignado').toList()
      ..sort(
        (a, b) => (a.queuePosition ?? (1 << 30)).compareTo(
          b.queuePosition ?? (1 << 30),
        ),
      );
    final history = items
        .where(
          (m) =>
              !activeStates.contains(m.managementStatus) &&
              m.managementStatus != 'asignado',
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('GESTIÓN ACTIVA', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (active.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('SIN GESTIÓN ACTIVA'),
            ),
          )
        else
          ...active.map((m) => _ManagementTile(management: m)),
        const SizedBox(height: 20),
        Text(
          active.isEmpty ? 'PRÓXIMOS PEDIDOS' : 'EN COLA',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (queued.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes pedidos en cola.'),
            ),
          )
        else
          ...queued.map(
            (m) => _ManagementTile(management: m, showQueuePosition: true),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('HISTORIAL', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...history.map((m) => _ManagementTile(management: m)),
        ],
      ],
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.management,
    this.showQueuePosition = false,
  });

  final ManagementDto management;
  final bool showQueuePosition;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: () => context.push('/managements/${management.id}'),
      title: Text(management.localName ?? 'Local'),
      subtitle: Text(
        '${management.driverName ?? ''} · ${management.vehiclePlate ?? ''}\n${_status(management.managementStatus)}',
      ),
      leading: showQueuePosition && management.queuePosition != null
          ? CircleAvatar(child: Text('${management.queuePosition}'))
          : null,
      isThreeLine: true,
    ),
  );
}

enum _ManagementDetailLookup { loading, loaded, notFound, error }

class ManagementDetailScreen extends ConsumerStatefulWidget {
  const ManagementDetailScreen({super.key, required this.managementId});

  final String managementId;

  @override
  ConsumerState<ManagementDetailScreen> createState() =>
      _ManagementDetailScreenState();
}

class _ManagementDetailScreenState
    extends ConsumerState<ManagementDetailScreen> {
  var _lookup = _ManagementDetailLookup.loading;
  ManagementDto? _management;
  var _refreshingDetail = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('management-detail route id=${widget.managementId}');
    }
    Future.microtask(_loadManagement);
  }

  Future<bool> _loadManagement({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        if (refresh) {
          _refreshingDetail = true;
        } else {
          _lookup = _ManagementDetailLookup.loading;
          _management = null;
        }
      });
    }

    try {
      final management = await ref
          .read(managementsProvider.notifier)
          .detail(widget.managementId);
      if (!mounted) return management != null;

      if (management == null) {
        setState(() {
          _lookup = _ManagementDetailLookup.notFound;
          _management = null;
          _refreshingDetail = false;
        });
        if (kDebugMode) debugPrint('management-detail loaded=false');
        return false;
      }

      setState(() {
        _lookup = _ManagementDetailLookup.loaded;
        _management = management;
        _refreshingDetail = false;
      });
      if (kDebugMode) debugPrint('management-detail loaded=true');
      if (kDebugMode && refresh) {
        debugPrint(
          'management-detail refresh: managementId=${management.id} '
          'status=${management.managementStatus}',
        );
      }
      return true;
    } catch (_) {
      if (!mounted) return false;

      if (refresh && _management != null) {
        setState(() => _refreshingDetail = false);
        _showRefreshFailure();
      } else {
        setState(() {
          _lookup = _ManagementDetailLookup.error;
          _management = null;
          _refreshingDetail = false;
        });
      }
      return false;
    }
  }

  Future<void> _changeStatus(String next) async {
    final management = _management;
    if (management == null) return;

    final session = ref.read(sessionProvider).session;
    if (kDebugMode && session != null) {
      debugPrint(
        'management action role=${session.user.role} '
        'status=${management.managementStatus}',
      );
    }
    final updated = await ref
        .read(managementsProvider.notifier)
        .status(management.id, next);
    if (!updated) {
      if (mounted) {
        final message =
            ref.read(managementsProvider).error ??
            'No fue posible actualizar la gestión.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    await _loadManagement(refresh: true);
    await ref.read(managementsProvider.notifier).load();
  }

  void _showRefreshFailure() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'La gestión se actualizó, pero no fue posible refrescar los datos.',
          ),
          action: SnackBarAction(
            label: 'REINTENTAR',
            onPressed: _loadManagement,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext c) {
    if (_lookup == _ManagementDetailLookup.loading) {
      return _detailScaffold(
        c,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_lookup == _ManagementDetailLookup.notFound) {
      return _detailScaffold(
        c,
        body: const Center(child: Text('La gestión ya no está disponible.')),
      );
    }
    if (_lookup == _ManagementDetailLookup.error || _management == null) {
      return _detailScaffold(
        c,
        body: Center(
          child: TextButton(
            onPressed: _loadManagement,
            child: const Text('REINTENTAR CARGA DE LA GESTIÓN'),
          ),
        ),
      );
    }

    final m = _management!;
    final session = ref.watch(sessionProvider).session;
    final isDriver =
        session?.user.role == 'chofer' && session?.user.id == m.driverUserId;
    final next = isDriver
        ? {
            'asignado': 'aceptado',
            'aceptado': 'en_camino',
            'en_camino': 'en_gestion',
            'en_gestion': 'completado',
          }[m.managementStatus]
        : null;
    final processing =
        ref.watch(managementsProvider).saving || _refreshingDetail;

    return Scaffold(
      appBar: _appBar(c),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Pedido: ${m.orderId}'),
              Text('Local: ${m.localName ?? ''}'),
              Text('Chofer: ${m.driverName ?? ''}'),
              Text('Vehículo: ${m.vehiclePlate ?? ''}'),
              Text('Destino: ${m.destination ?? ''}'),
              Text('Descripción: ${m.description ?? ''}'),
              Text('Prioridad: ${_priority(m.priority)}'),
              Text('Estado: ${_status(m.managementStatus)}'),
              if (m.managementStatus == 'asignado' && m.queuePosition != null)
                Text('Posición en cola: ${m.queuePosition}'),
              Text('Factura/Solicitud: ${m.invoiceRequest ?? ''}'),
              Text('Contacto: ${m.contactNumber ?? ''}'),
              Text('Observaciones: ${m.notes ?? ''}'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => c.push('/orders/${m.orderId}'),
                child: const Text('VER PEDIDO'),
              ),
              if (m.latitude != null && m.longitude != null) ...[
                OutlinedButton(
                  onPressed: () => showDialog(
                    context: c,
                    builder: (_) => AlertDialog(
                      content: SizedBox(
                        height: 320,
                        width: 500,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(m.latitude!, m.longitude!),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(m.latitude!, m.longitude!),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('VER DESTINO'),
                ),
                FilledButton.tonal(
                  onPressed: () => _openMaps(m.latitude!, m.longitude!),
                  child: const Text('IR CON MAPS'),
                ),
              ],
              const SizedBox(height: 16),
              Text('Historial', style: Theme.of(c).textTheme.titleMedium),
              if (m.events.isEmpty)
                const Text('No hay eventos registrados.')
              else
                ...m.events.map(
                  (e) => Text(
                    '${_status(e.status)} - '
                    '${e.createdAt.day.toString().padLeft(2, '0')}/'
                    '${e.createdAt.month.toString().padLeft(2, '0')}/'
                    '${e.createdAt.year} '
                    '${e.createdAt.hour.toString().padLeft(2, '0')}:'
                    '${e.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              if (next != null)
                FilledButton(
                  onPressed: processing
                      ? null
                      : () async {
                          if (next == 'completado') {
                            final yes = await showDialog<bool>(
                              context: c,
                              builder: (x) => AlertDialog(
                                title: const Text('Completar gestión'),
                                content: const Text(
                                  '¿Confirmas que la gestión fue completada?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(x, false),
                                    child: const Text('CANCELAR'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(x, true),
                                    child: const Text('CONFIRMAR'),
                                  ),
                                ],
                              ),
                            );
                            if (yes != true) return;
                          }
                          await _changeStatus(next);
                        },
                  child: Text(
                    processing
                        ? 'PROCESANDO...'
                        : next == 'aceptado'
                        ? 'ACEPTAR'
                        : next == 'en_camino'
                        ? 'EN CAMINO'
                        : next == 'en_gestion'
                        ? 'INICIAR GESTIÓN'
                        : 'COMPLETAR',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _detailScaffold(BuildContext context, {required Widget body}) =>
      Scaffold(appBar: _appBar(context), body: body);

  AppBar _appBar(BuildContext context) => AppBar(
    title: const Text('Detalle de gestión'),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Volver',
      onPressed: () =>
          context.canPop() ? context.pop() : context.go('/managements'),
    ),
  );

  Future<void> _openMaps(double latitude, double longitude) async {
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });

    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showMapsFailure();
    } catch (_) {
      if (mounted) _showMapsFailure();
    }
  }

  void _showMapsFailure() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No fue posible abrir la aplicación de mapas.'),
        ),
      );
  }
}

String _status(String x) =>
    {
      'asignado': 'Asignado',
      'aceptado': 'Aceptado',
      'en_camino': 'En camino',
      'en_gestion': 'En gestión',
      'completado': 'Completado',
      'cancelado': 'Cancelado',
    }[x] ??
    x;
String _priority(String? x) =>
    {'baja': 'Baja', 'normal': 'Normal', 'urgente': 'Urgente'}[x] ?? '';
