import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/vehicle_type.dart';
import '../../attendance/data/dtos/location_dto.dart';
import '../../authentication/providers/session_provider.dart';
import '../../companies/data/dtos/company_dto.dart';
import '../../dashboard/app_shell.dart';
import '../data/dtos/fleet_driver_location_dto.dart';
import '../providers/fleet_locations_provider.dart';
import 'fleet_map_locations.dart';
import 'fleet_map_visuals.dart';

class FleetMapScreen extends ConsumerStatefulWidget {
  const FleetMapScreen({super.key});

  @override
  ConsumerState<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends ConsumerState<FleetMapScreen>
    with WidgetsBindingObserver {
  final _controller = MapController();
  Timer? _timer;
  bool _foreground = true;
  bool _showDrivers = true;
  bool _showLocations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(fleetLocationsProvider.notifier).loadMap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  bool get _canPoll {
    final role = ref.read(sessionProvider).session?.user.role;
    return _foreground && {'admin', 'supervisor', 'super_admin'}.contains(role);
  }

  void _syncTimer() {
    if (_canPoll && _timer == null) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => ref.read(fleetLocationsProvider.notifier).load(),
      );
    } else if (!_canPoll) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _refreshMap() async {
    await ref.read(fleetLocationsProvider.notifier).refreshAll();
    if (!mounted) return;
    final message = ref.read(fleetLocationsProvider).errorMessage ??
        'Mapa actualizado';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _selectDriver(
    FleetDriverLocationDto driver,
    List<LocationDto> locations,
  ) {
    if (driver.hasLocation) {
      _controller.move(LatLng(driver.latitude!, driver.longitude!), 15);
    }
    _showDetail(_DriverDetail(driver: driver, locations: locations));
  }

  void _selectLocation(
    LocationDto location,
    List<FleetDriverLocationDto> drivers,
  ) {
    _controller.move(LatLng(location.latitud, location.longitud), 15);
    _showDetail(_LocationDetail(location: location, drivers: drivers));
  }

  void _showDetail(Widget detail) {
    if (MediaQuery.sizeOf(context).width < 700) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => detail,
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: detail),
      );
    }
  }

  void _fit(List<FleetDriverLocationDto> drivers, List<LocationDto> locations) {
    final points = <LatLng>[
      if (_showDrivers)
        for (final driver in drivers.where((driver) => driver.hasLocation))
          LatLng(driver.latitude!, driver.longitude!),
      if (_showLocations)
        for (final location in locations.where(
          (location) =>
              hasValidMapCoordinates(location.latitud, location.longitud),
        ))
          LatLng(location.latitud, location.longitud),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.single, 14);
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 14,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTimer();
    final state = ref.watch(fleetLocationsProvider);
    return AppShell(
      title: 'Mapa de Flota',
      showHomeAction: true,
      child: state.isLoading && state.isStaticLoading && state.drivers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshMap,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (state.errorMessage != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        title: Text(state.errorMessage!),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reintentar',
                          onPressed: _refreshMap,
                        ),
                      ),
                    ),
                  _Map(
                    controller: _controller,
                    drivers: state.drivers,
                    locations: state.locations,
                    companies: state.companies,
                    showDrivers: _showDrivers,
                    showLocations: _showLocations,
                    onShowDriversChanged: (value) =>
                        setState(() => _showDrivers = value),
                    onShowLocationsChanged: (value) =>
                        setState(() => _showLocations = value),
                    onDriverTap: (driver) =>
                        _selectDriver(driver, state.locations),
                    onLocationTap: (location) =>
                        _selectLocation(location, state.drivers),
                    onFit: () => _fit(state.drivers, state.locations),
                    loading: state.isLoading || state.isStaticLoading,
                    onRefresh: _refreshMap,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choferes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...state.drivers.map(
                    (driver) => Card(
                      child: ListTile(
                        leading: Icon(
                          driver.hasLocation
                              ? vehicleTypeIcon(driver.vehicleType)
                              : Icons.location_off,
                          color: _driverColor(
                            context,
                            fleetMapVisualState(driver),
                          ),
                        ),
                        title: Text(driver.driverName),
                        subtitle: Text(
                          '${_vehicle(driver)}\n${_status(driver)} · Posición ${relativeTimeLabel(driver.capturedAt, now: DateTime.now())}',
                        ),
                        isThreeLine: true,
                        onTap: () => _selectDriver(driver, state.locations),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({
    required this.controller,
    required this.drivers,
    required this.locations,
    required this.companies,
    required this.showDrivers,
    required this.showLocations,
    required this.onShowDriversChanged,
    required this.onShowLocationsChanged,
    required this.onDriverTap,
    required this.onLocationTap,
    required this.onFit,
    required this.loading,
    required this.onRefresh,
  });

  final MapController controller;
  final List<FleetDriverLocationDto> drivers;
  final List<LocationDto> locations;
  final List<CompanyDto> companies;
  final bool showDrivers;
  final bool showLocations;
  final ValueChanged<bool> onShowDriversChanged;
  final ValueChanged<bool> onShowLocationsChanged;
  final ValueChanged<FleetDriverLocationDto> onDriverTap;
  final ValueChanged<LocationDto> onLocationTap;
  final VoidCallback onFit;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visibleDrivers = drivers
        .where((driver) => driver.hasLocation)
        .toList();
    final visibleLocations = locations
        .where(
          (location) =>
              hasValidMapCoordinates(location.latitud, location.longitud),
        )
        .toList();
    final companiesById = {
      for (final company in companies) company.id: company,
    };
    final initial = visibleDrivers.isNotEmpty
        ? LatLng(
            visibleDrivers.first.latitude!,
            visibleDrivers.first.longitude!,
          )
        : visibleLocations.isNotEmpty
        ? LatLng(
            visibleLocations.first.latitud,
            visibleLocations.first.longitud,
          )
        : null;
    if (initial == null) {
      return const Card(
        child: SizedBox(
          height: 260,
          child: Center(
            child: Text('No hay ubicaciones disponibles para mostrar.'),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 400,
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(initialCenter: initial, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fleet_control',
                ),
                if (showDrivers)
                  MarkerLayer(
                    markers: [
                      for (final driver in visibleDrivers)
                        Marker(
                          point: LatLng(driver.latitude!, driver.longitude!),
                          width: 62,
                          height: 68,
                          child: Tooltip(
                            message:
                                '${driver.driverName} · ${_status(driver)}',
                            child: InkWell(
                              onTap: () => onDriverTap(driver),
                              customBorder: const CircleBorder(),
                              child: _DriverMarker(driver),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (showLocations)
                  MarkerLayer(
                    markers: [
                      for (final location in visibleLocations)
                        Marker(
                          point: LatLng(location.latitud, location.longitud),
                          width: 54,
                          height: 62,
                          child: Tooltip(
                            message: location.nombre,
                            child: InkWell(
                              onTap: () => onLocationTap(location),
                              customBorder: const CircleBorder(),
                              child: _LocationMarker(
                                location: location,
                                company: companiesById[location.empresaId],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => unawaited(
                        launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _LayerControl(
                showDrivers: showDrivers,
                showLocations: showLocations,
                onShowDriversChanged: onShowDriversChanged,
                onShowLocationsChanged: onShowLocationsChanged,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'fit',
                    tooltip: 'Ver todo',
                    onPressed: onFit,
                    child: const Icon(Icons.fit_screen_outlined),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'refresh',
                    tooltip: 'Actualizar mapa',
                    onPressed: loading ? null : () => unawaited(onRefresh()),
                    child: Icon(loading ? Icons.hourglass_top : Icons.refresh),
                  ),
                ],
              ),
            ),
            const Positioned(bottom: 10, left: 10, child: _Legend()),
          ],
        ),
      ),
    );
  }
}

class _LayerControl extends StatelessWidget {
  const _LayerControl({
    required this.showDrivers,
    required this.showLocations,
    required this.onShowDriversChanged,
    required this.onShowLocationsChanged,
  });

  final bool showDrivers;
  final bool showLocations;
  final ValueChanged<bool> onShowDriversChanged;
  final ValueChanged<bool> onShowLocationsChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LayerToggle(
            label: 'Choferes',
            value: showDrivers,
            onChanged: onShowDriversChanged,
          ),
          _LayerToggle(
            label: 'Puntos de venta',
            value: showLocations,
            onChanged: onShowLocationsChanged,
          ),
        ],
      ),
    ),
  );
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: (value) => onChanged(value ?? false)),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(8),
    child: const Padding(
      padding: EdgeInsets.all(6),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          _LegendItem(icon: Icons.navigation, label: 'Vehículo'),
          _LegendItem(icon: Icons.storefront, label: 'Punto de venta'),
          _LegendItem(icon: Icons.cloud_off, label: 'Offline'),
          _LegendItem(icon: Icons.warning_amber, label: 'GPS antigua'),
        ],
      ),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker(this.driver);

  final FleetDriverLocationDto driver;

  @override
  Widget build(BuildContext context) {
    final state = fleetMapVisualState(driver);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _driverColor(context, state),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Transform.rotate(
            angle: headingRadians(driver.headingDegrees),
            child: Icon(
              state == FleetMapVisualState.offline
                  ? Icons.directions_car_outlined
                  : Icons.navigation,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          child: Chip(
            label: Text(
              isStalePosition(driver.capturedAt, now: DateTime.now())
                  ? 'GPS antigua'
                  : _visual(state),
              style: const TextStyle(fontSize: 9),
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker({required this.location, required this.company});

  final LocationDto location;
  final CompanyDto? company;

  @override
  Widget build(BuildContext context) {
    final color = localMarkerColor(
      company?.localMarkerColor,
      Theme.of(context).colorScheme.secondary,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Icon(
            localMarkerIcon(company?.localMarkerIcon),
            color: Colors.white,
          ),
        ),
        Positioned(
          bottom: 0,
          child: Icon(
            location.isActive ? Icons.check_circle : Icons.pause_circle,
            size: 17,
            color: location.isActive
                ? Colors.green.shade700
                : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _DriverDetail extends StatelessWidget {
  const _DriverDetail({required this.driver, required this.locations});

  final FleetDriverLocationDto driver;
  final List<LocationDto> locations;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nearest = nearestLocationsForDriver(driver, locations);
    return _DetailCard(
      title: driver.driverName,
      subtitle: _vehicle(driver),
      children: [
        _DetailRow(Icons.work_outline, 'Estado', _status(driver)),
        _DetailRow(Icons.speed, 'Velocidad', speedLabel(driver.speedMps)),
        _DetailRow(
          Icons.gps_fixed,
          'GPS',
          accuracyLabel(driver.accuracyMeters),
        ),
        _DetailRow(
          Icons.wifi,
          'Última comunicación',
          relativeTimeLabel(driver.lastSeenAt, now: now),
        ),
        _DetailRow(
          Icons.location_on_outlined,
          'Última posición',
          relativeTimeLabel(driver.capturedAt, now: now),
        ),
        const Divider(),
        if (nearest.isEmpty)
          const _DetailRow(
            Icons.storefront_outlined,
            'Local más cercano',
            'Sin puntos de venta con ubicación disponible',
          )
        else ...[
          _DetailRow(
            Icons.storefront_outlined,
            'Local más cercano',
            nearest.first.value.nombre,
          ),
          _DetailRow(
            Icons.straighten,
            'Distancia',
            distanceLabel(nearest.first.meters),
          ),
        ],
        if (isStalePosition(driver.capturedAt, now: now))
          const Chip(
            avatar: Icon(Icons.warning_amber, size: 18),
            label: Text('Posición antigua'),
          ),
      ],
    );
  }
}

class _LocationDetail extends StatelessWidget {
  const _LocationDetail({required this.location, required this.drivers});

  final LocationDto location;
  final List<FleetDriverLocationDto> drivers;

  @override
  Widget build(BuildContext context) {
    final nearest = nearestDriversForLocation(location, drivers);
    return _DetailCard(
      title: location.nombre,
      subtitle: 'Punto de venta',
      children: [
        if (location.direccion != null)
          _DetailRow(Icons.place_outlined, 'Dirección', location.direccion!),
        _DetailRow(
          location.isActive
              ? Icons.check_circle_outline
              : Icons.pause_circle_outline,
          'Estado',
          location.isActive ? 'Activo' : 'Inactivo',
        ),
        const Divider(),
        if (nearest.isEmpty)
          const _DetailRow(
            Icons.person_off_outlined,
            'Chofer más cercano',
            'Sin choferes con ubicación disponible',
          )
        else ...[
          _DetailRow(
            Icons.person_outline,
            'Chofer más cercano',
            nearest.first.value.driverName,
          ),
          _DetailRow(
            Icons.straighten,
            'Distancia',
            distanceLabel(nearest.first.meters),
          ),
        ],
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(subtitle),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text('$label: '),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

Color _driverColor(BuildContext context, FleetMapVisualState state) =>
    switch (state) {
      FleetMapVisualState.available => Theme.of(context).colorScheme.primary,
      FleetMapVisualState.active => Theme.of(context).colorScheme.tertiary,
      FleetMapVisualState.offline => Theme.of(context).colorScheme.outline,
    };

String _visual(FleetMapVisualState state) => switch (state) {
  FleetMapVisualState.available => 'Disponible',
  FleetMapVisualState.active => 'En viaje',
  FleetMapVisualState.offline => 'Offline',
};

String _status(FleetDriverLocationDto driver) {
  final operational = switch (driver.operationalStatus) {
    'asignado' => 'Asignado',
    'aceptado' => 'Aceptado',
    'en_camino' => 'En camino',
    'en_gestion' => 'En gestión',
    _ => 'Disponible',
  };
  return '${_visual(fleetMapVisualState(driver))} · $operational';
}

String _vehicle(FleetDriverLocationDto driver) => driver.vehiclePlate == null
    ? 'Sin vehículo asignado'
    : '${driver.vehiclePlate} · ${vehicleTypeLabel(driver.vehicleType)}';
