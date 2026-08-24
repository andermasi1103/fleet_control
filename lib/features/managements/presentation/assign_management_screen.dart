import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../orders/data/dtos/order_dto.dart';
import '../../vehicles/data/dtos/vehicle_dto.dart';
import '../../vehicles/providers/vehicles_provider.dart'
    show vehiclesDataSourceProvider;
import '../../authentication/providers/session_provider.dart';
import '../../user_vehicles/providers/user_vehicles_provider.dart';
import '../data/dtos/management_dto.dart';
import '../providers/managements_provider.dart';

class AssignManagementScreen extends ConsumerStatefulWidget {
  const AssignManagementScreen({super.key, required this.order});
  final OrderDto order;
  @override
  ConsumerState<AssignManagementScreen> createState() => _A();
}

class _A extends ConsumerState<AssignManagementScreen> {
  String? d, v;
  List<VehicleDto> vehicles = const [];
  bool _loadingHabitualVehicle = false;
  bool _vehicleChangedManually = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(managementsProvider.notifier)
          .drivers(widget.order.companyId);
      final token = ref.read(sessionProvider).session?.sessionToken;
      if (token != null) {
        final all = await ref
            .read(vehiclesDataSourceProvider)
            .getVehicles(sessionToken: token);
        if (mounted) {
          setState(
            () => vehicles = all
                .where(
                  (x) => x.companyId == widget.order.companyId && x.isActive,
                )
                .toList(),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = ref.watch(managementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar gestión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Local: ${widget.order.locationName ?? ''}'),
              Text('Destino: ${widget.order.destination ?? ''}'),
              Text('Descripción: ${widget.order.description ?? ''}'),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: d,
                decoration: const InputDecoration(labelText: 'Chofer *'),
                items: s.drivers
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text('${x.name} · ${x.username}'),
                      ),
                    )
                    .toList(),
                onChanged: s.saving
                    ? null
                    : (x) {
                        setState(() {
                          d = x;
                          v = null;
                          _vehicleChangedManually = false;
                        });
                        if (x != null) _suggestHabitualVehicle(x);
                      },
              ),
              const SizedBox(height: 16),
              if (s.drivers.isEmpty)
                const Text('No hay choferes disponibles para esta empresa.'),
              DropdownButtonFormField<String>(
                initialValue: v,
                decoration: const InputDecoration(labelText: 'Vehículo *'),
                items: vehicles
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text(
                          '${x.plate}${x.brand == null ? '' : ' · ${x.brand} ${x.model ?? ''}'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: s.saving
                    ? null
                    : (x) => setState(() {
                        v = x;
                        _vehicleChangedManually = true;
                      }),
              ),
              if (_loadingHabitualVehicle)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Buscando vehículo habitual del chofer...'),
                ),
              if (vehicles.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No hay vehículos activos disponibles para esta empresa.',
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: s.saving || d == null || v == null
                    ? null
                    : () => _save(),
                child: Text(s.saving ? 'ASIGNANDO...' : 'ASIGNAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await ref
        .read(managementsProvider.notifier)
        .create(CreateManagementRequest(widget.order.id, d!, v!));
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gestión asignada correctamente.')),
      );
      context.pop();
    }
  }

  Future<void> _suggestHabitualVehicle(String driverId) async {
    final token = ref.read(sessionProvider).session?.sessionToken;
    if (token == null) return;
    setState(() => _loadingHabitualVehicle = true);
    try {
      final lookup = await ref
          .read(userVehiclesDataSourceProvider)
          .get(sessionToken: token, userId: driverId);
      final vehicleId = lookup.assignment?.vehicleId;
      if (!mounted || d != driverId || _vehicleChangedManually) return;
      if (vehicleId != null &&
          vehicles.any((vehicle) => vehicle.id == vehicleId)) {
        setState(() => v = vehicleId);
      }
    } catch (_) {
      // La asignación manual sigue disponible si no se puede obtener la sugerencia.
    } finally {
      if (mounted && d == driverId) {
        setState(() => _loadingHabitualVehicle = false);
      }
    }
  }
}
