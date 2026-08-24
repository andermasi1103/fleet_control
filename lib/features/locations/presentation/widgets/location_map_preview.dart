import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationMapPreview extends StatelessWidget {
  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.onPointSelected,
    this.tileProvider,
  });

  final double? latitude;
  final double? longitude;
  final double? radiusMeters;
  final ValueChanged<LatLng> onPointSelected;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = _hasValidCoordinates;
    final point = hasCoordinates
        ? LatLng(latitude!, longitude!)
        : LatLng(-25.2637, -57.5759);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).width >= 760 ? 350 : 250,
            child: FlutterMap(
              key: ValueKey(
                '${point.latitude}:${point.longitude}:$radiusMeters:$hasCoordinates',
              ),
              options: MapOptions(
                initialCenter: point,
                initialZoom: hasCoordinates ? 16 : 12,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, tappedPoint) {
                  if (kDebugMode) {
                    debugPrint(
                      'location-map tap lat=${tappedPoint.latitude} lng=${tappedPoint.longitude}',
                    );
                  }
                  onPointSelected(tappedPoint);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fleet_control',
                  tileProvider: tileProvider,
                ),
                if (hasCoordinates)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        radius: radiusMeters ?? 0,
                        color: Colors.blue.withValues(alpha: 0.18),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (hasCoordinates)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Pulsa en el mapa para cambiar la ubicación del local.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
}
