import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../authentication/providers/session_provider.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/location_dto.dart';
import '../providers/attendance_provider.dart';
import '../providers/attendance_state.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final MapController _mapController = MapController();
  LatLng? _lastMapCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).session;
    final user = session?.user;
    final state = ref.watch(attendanceProvider);
    final location = state.selectedLocation;
    final canMark =
        session != null &&
        !session.isExpired &&
        location != null &&
        state.position != null &&
        state.status != null &&
        !state.isLoading &&
        !state.isMarking &&
        state.isWithinGeofence == true;
    final markUnavailableReason = session == null || session.isExpired
        ? 'Tu sesión ha vencido. Inicia sesión nuevamente.'
        : state.markUnavailableReason;

    if (location != null || state.position != null) {
      _centerMap(location, state);
    }

    return AppShell(
      title: 'Asistencia',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Asistencia',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Registra tu entrada o salida según tu ubicación.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _UserCard(
                  name: user?.displayName ?? 'Usuario no disponible',
                  usuario: user?.usuario ?? '-',
                ),
                if (state.locationsErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(
                    message: state.locationsErrorMessage!,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
                if (state.statusErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  _MessageCard(
                    message: state.statusErrorMessage!,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
                const SizedBox(height: 20),
                if (state.isInitializing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (state.locations.isNotEmpty)
                    _LocationSelector(
                      locations: state.locations,
                      selectedLocation: location,
                      onChanged: (id) {
                        if (id != null) {
                          ref
                              .read(attendanceProvider.notifier)
                              .selectLocation(id);
                        }
                      },
                    )
                  else if (state.locationsErrorMessage == null)
                    const _EmptyLocationsCard(),
                  if (location != null) ...[
                    const SizedBox(height: 12),
                    _LocationDetails(location: location),
                  ],
                  const SizedBox(height: 16),
                  if (state.locationErrorMessage != null) ...[
                    _MessageCard(
                      message: state.locationErrorMessage!,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _PositionDetails(state: state, location: location),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.isLoadingLocation || state.isMarking
                        ? null
                        : () => ref
                              .read(attendanceProvider.notifier)
                              .refreshLocation(),
                    icon: state.isLoadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                    label: const Text('Actualizar ubicación'),
                  ),
                  if (location != null || state.position != null) ...[
                    const SizedBox(height: 16),
                    _AttendanceMap(
                      controller: _mapController,
                      location: location,
                      state: state,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ActionDetails(state: state),
                  if (!canMark && markUnavailableReason != null) ...[
                    const SizedBox(height: 8),
                    Text(markUnavailableReason),
                  ],
                  if (state.actionErrorMessage != null) ...[
                    const SizedBox(height: 8),
                    _MessageCard(
                      message: state.actionErrorMessage!,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: canMark ? () => _markAttendance(context) : null,
                    icon: state.isMarking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_reg),
                    label: Text(
                      state.isMarking
                          ? 'REGISTRANDO...'
                          : _actionLabel(state.status?.nextAction),
                    ),
                  ),
                ],
                if (state.lastAttendance != null) ...[
                  const SizedBox(height: 20),
                  _LastAttendanceCard(
                    fechaHora: state.lastAttendance!.fechaHora,
                    tipo: state.lastAttendance!.tipo,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _centerMap(LocationDto? location, AttendanceState state) {
    final position = state.position;
    if (location == null && position == null) return;
    final center = location == null
        ? LatLng(position!.latitude, position.longitude)
        : position == null
        ? LatLng(location.latitud, location.longitud)
        : LatLng(
            (location.latitud + position.latitude) / 2,
            (location.longitud + position.longitude) / 2,
          );
    if (_lastMapCenter?.latitude == center.latitude &&
        _lastMapCenter?.longitude == center.longitude) {
      return;
    }
    _lastMapCenter = center;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (position == null || location == null) {
          _mapController.move(center, 16);
        } else {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: [
                LatLng(location.latitud, location.longitud),
                LatLng(position.latitude, position.longitude),
              ],
              padding: const EdgeInsets.all(48),
              maxZoom: 16,
            ),
          );
        }
      }
    });
  }

  Future<void> _markAttendance(BuildContext context) async {
    final success = await ref
        .read(attendanceProvider.notifier)
        .markAttendance();
    if (!context.mounted) {
      return;
    }
    final state = ref.read(attendanceProvider);
    final message = success
        ? state.successMessage ?? 'Asistencia registrada correctamente.'
        : state.actionErrorMessage ?? 'No fue posible registrar la asistencia.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Colors.green
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _actionLabel(String? nextAction) =>
      nextAction == 'salida' ? 'MARCAR SALIDA' : 'MARCAR ENTRADA';
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.name, required this.usuario});

  final String name;
  final String usuario;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Usuario: $usuario'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.locations,
    required this.selectedLocation,
    required this.onChanged,
  });

  final List<LocationDto> locations;
  final LocationDto? selectedLocation;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey(selectedLocation?.id),
    initialValue: selectedLocation?.id,
    decoration: const InputDecoration(labelText: 'Local'),
    items: locations
        .map(
          (location) => DropdownMenuItem(
            value: location.id,
            child: Text(location.nombre),
          ),
        )
        .toList(growable: false),
    onChanged: locations.length > 1 ? onChanged : null,
  );
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({required this.location});

  final LocationDto location;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location.nombre, style: Theme.of(context).textTheme.titleMedium),
          if (location.empresaNombre != null) ...[
            const SizedBox(height: 4),
            Text(location.empresaNombre!),
          ],
          if (location.direccion != null) ...[
            const SizedBox(height: 4),
            Text('Dirección: ${location.direccion}'),
          ],
          const SizedBox(height: 4),
          Text('Radio: ${location.radioMetros.round()} m'),
        ],
      ),
    ),
  );
}

class _AttendanceMap extends StatelessWidget {
  const _AttendanceMap({
    required this.controller,
    required this.location,
    required this.state,
  });

  final MapController controller;
  final LocationDto? location;
  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    final locationPoint = location == null
        ? null
        : LatLng(location!.latitud, location!.longitud);
    final position = state.position;
    final userPoint = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    final isInside = state.isWithinGeofence == true;
    final initialCenter = userPoint ?? locationPoint!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).width >= 700 ? 360 : 300,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(initialCenter: initialCenter, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fleet_control',
            ),
            if (locationPoint != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: locationPoint,
                    radius: location!.radioMetros,
                    color: (isInside ? Colors.green : Colors.red).withValues(
                      alpha: 0.18,
                    ),
                    borderColor: isInside ? Colors.green : Colors.red,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (locationPoint != null)
                  Marker(
                    point: locationPoint,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 42,
                    ),
                  ),
                if (userPoint != null)
                  Marker(
                    point: userPoint,
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.my_location,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionDetails extends StatelessWidget {
  const _PositionDetails({required this.state, required this.location});

  final AttendanceState state;
  final LocationDto? location;

  @override
  Widget build(BuildContext context) {
    final position = state.position;
    final distance = state.distanceMeters;
    final isInside = state.isWithinGeofence;
    final color = isInside == true
        ? Colors.green
        : isInside == false
        ? Colors.red
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu ubicación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              position == null
                  ? state.isLoadingLocation
                        ? 'Obteniendo ubicación...'
                        : 'Ubicación no disponible.'
                  : 'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}\nPrecisión: ± ${position.accuracy.toStringAsFixed(0)} m',
            ),
            if (location != null) ...[
              const SizedBox(height: 12),
              Text(
                'Distancia al local: ${distance == null ? '-' : '${distance.round()} m'}',
              ),
              Text('Radio permitido: ${location!.radioMetros.round()} m'),
              const SizedBox(height: 8),
              Text(
                isInside == null
                    ? 'Geocerca: esperando ubicación'
                    : isInside
                    ? 'Geocerca: Dentro de la geocerca'
                    : 'Geocerca: Fuera de la geocerca',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionDetails extends StatelessWidget {
  const _ActionDetails({required this.state});

  final AttendanceState state;

  @override
  Widget build(BuildContext context) {
    final action = state.status?.nextAction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          action == null
              ? 'Estado de jornada: no disponible'
              : 'Próxima acción: ${action == 'entrada' ? 'Entrada' : 'Salida'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _EmptyLocationsCard extends StatelessWidget {
  const _EmptyLocationsCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text('No hay locales disponibles para registrar asistencia.'),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: 0.1),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: TextStyle(color: color)),
    ),
  );
}

class _LastAttendanceCard extends StatelessWidget {
  const _LastAttendanceCard({required this.fechaHora, required this.tipo});

  final DateTime fechaHora;
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final localDateTime = fechaHora.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Última asistencia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Fecha: ${DateFormat('dd/MM/yyyy').format(localDateTime)}'),
            Text('Hora: ${DateFormat.Hm().format(localDateTime)}'),
            Text('Tipo: ${tipo.toUpperCase()}'),
          ],
        ),
      ),
    );
  }
}
