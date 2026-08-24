import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/utils/vehicle_type.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/fleet_driver_location_dto.dart';
import '../providers/fleet_locations_provider.dart';

class FleetMapScreen extends ConsumerStatefulWidget {
  const FleetMapScreen({super.key});

  @override
  ConsumerState<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends ConsumerState<FleetMapScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(fleetLocationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fleetLocationsProvider);

    return AppShell(
      title: 'Mapa de Flota',
      showHomeAction: true,
      child: state.isLoading && state.drivers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(fleetLocationsProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (state.errorMessage != null)
                    _FleetMapError(
                      message: state.errorMessage!,
                      onRetry: ref.read(fleetLocationsProvider.notifier).load,
                    ),
                  if (state.errorMessage != null) const SizedBox(height: 12),
                  _FleetMap(
                    drivers: state.drivers,
                    onDriverTap: (driver) =>
                        _showDriverDetails(context, driver),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choferes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.drivers.isEmpty && state.errorMessage == null)
                    const _EmptyFleet()
                  else
                    ...state.drivers.map(
                      (driver) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DriverLocationCard(driver: driver),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FleetMap extends StatelessWidget {
  const _FleetMap({required this.drivers, required this.onDriverTap});

  final List<FleetDriverLocationDto> drivers;
  final ValueChanged<FleetDriverLocationDto> onDriverTap;

  @override
  Widget build(BuildContext context) {
    final locatedDrivers = drivers
        .where((driver) => driver.hasLocation)
        .toList();
    if (locatedDrivers.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 240,
          child: Center(
            child: Text(
              'No hay choferes con ubicación disponible en este momento.',
            ),
          ),
        ),
      );
    }

    final center = LatLng(
      locatedDrivers.first.latitude!,
      locatedDrivers.first.longitude!,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 340,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(
              markers: locatedDrivers
                  .map(
                    (driver) => Marker(
                      point: LatLng(driver.latitude!, driver.longitude!),
                      width: 54,
                      height: 54,
                      child: Tooltip(
                        message:
                            '${driver.driverName} · ${vehicleTypeLabel(driver.vehicleType)}\n'
                            '${_operationalLabel(driver.operationalStatus)} · '
                            '${_connectionLabel(driver.connectionStatus)}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onDriverTap(driver),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 21,
                                backgroundColor: _connectionColor(
                                  driver.connectionStatus,
                                ),
                                child: Icon(
                                  vehicleTypeIcon(driver.vehicleType),
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    driver.operationalStatus == 'disponible'
                                        ? Icons.check_circle
                                        : Icons.work_outline,
                                    size: 14,
                                    color: _connectionColor(
                                      driver.connectionStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverLocationCard extends StatelessWidget {
  const _DriverLocationCard({required this.driver});

  final FleetDriverLocationDto driver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          driver.hasLocation
              ? vehicleTypeIcon(driver.vehicleType)
              : Icons.location_off,
          color: _connectionColor(driver.connectionStatus),
        ),
        title: Text(driver.driverName),
        subtitle: Text(
          [
            if (driver.driverUsername.isNotEmpty) '@${driver.driverUsername}',
            _vehicleLabel(driver),
            '${_operationalLabel(driver.operationalStatus)} · ${_connectionLabel(driver.connectionStatus)}',
            _capturedAtLabel(driver.capturedAt),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: driver.hasLocation
            ? Icon(Icons.map_outlined, color: scheme.primary)
            : null,
        onTap: () => _showDriverDetails(context, driver),
      ),
    );
  }
}

void _showDriverDetails(BuildContext context, FleetDriverLocationDto driver) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(driver.driverName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usuario: ${driver.driverUsername.isEmpty ? '-' : driver.driverUsername}',
          ),
          Text(_vehicleLabel(driver)),
          Text('Tipo: ${vehicleTypeLabel(driver.vehicleType)}'),
          Text('Estado: ${_operationalLabel(driver.operationalStatus)}'),
          Text('Conexión: ${_connectionLabel(driver.connectionStatus)}'),
          Text(_capturedAtLabel(driver.capturedAt)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('CERRAR'),
        ),
      ],
    ),
  );
}

class _FleetMapError extends StatelessWidget {
  const _FleetMapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('REINTENTAR')),
        ],
      ),
    ),
  );
}

class _EmptyFleet extends StatelessWidget {
  const _EmptyFleet();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No hay choferes activos para mostrar.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Color _connectionColor(String status) {
  return switch (status) {
    'online' => Colors.green,
    'stale' => Colors.orange,
    _ => Colors.grey,
  };
}

String _connectionLabel(String status) {
  return switch (status) {
    'online' => 'Online',
    'stale' => 'Desactualizado',
    _ => 'Sin conexión',
  };
}

String _operationalLabel(String status) {
  return switch (status) {
    'asignado' => 'Asignado',
    'aceptado' => 'Aceptado',
    'en_camino' => 'En camino',
    'en_gestion' => 'En gestión',
    _ => 'Disponible',
  };
}

String _vehicleLabel(FleetDriverLocationDto driver) {
  final plate = driver.vehiclePlate;
  if (plate == null) return 'Sin vehículo asignado';
  return '$plate · ${vehicleTypeLabel(driver.vehicleType)}';
}

String _capturedAtLabel(DateTime? capturedAt) {
  if (capturedAt == null) return 'Sin ubicación reportada';
  final day = capturedAt.day.toString().padLeft(2, '0');
  final month = capturedAt.month.toString().padLeft(2, '0');
  final hour = capturedAt.hour.toString().padLeft(2, '0');
  final minute = capturedAt.minute.toString().padLeft(2, '0');
  return 'Actualizado: $day/$month $hour:$minute';
}
