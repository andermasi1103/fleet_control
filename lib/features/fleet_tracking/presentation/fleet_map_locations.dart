import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../attendance/data/dtos/location_dto.dart';
import '../data/dtos/fleet_driver_location_dto.dart';

const localMarkerIconKeys = <String>[
  'store',
  'storefront',
  'business',
  'grocery',
  'shopping',
  'location',
];

class DistanceResult<T> {
  const DistanceResult({required this.value, required this.meters});

  final T value;
  final double meters;
}

bool hasValidMapCoordinates(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

double? geodesicDistanceMeters({
  required double? fromLatitude,
  required double? fromLongitude,
  required double? toLatitude,
  required double? toLongitude,
}) {
  if (!hasValidMapCoordinates(fromLatitude, fromLongitude) ||
      !hasValidMapCoordinates(toLatitude, toLongitude)) {
    return null;
  }
  return const Distance().as(
    LengthUnit.Meter,
    LatLng(fromLatitude!, fromLongitude!),
    LatLng(toLatitude!, toLongitude!),
  );
}

String distanceLabel(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) {
    return 'Distancia no disponible';
  }
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

List<DistanceResult<LocationDto>> nearestLocationsForDriver(
  FleetDriverLocationDto driver,
  Iterable<LocationDto> locations,
) {
  if (!driver.hasLocation) return const [];
  return _sortedDistances<LocationDto>(locations, (location) {
    return geodesicDistanceMeters(
      fromLatitude: driver.latitude,
      fromLongitude: driver.longitude,
      toLatitude: location.latitud,
      toLongitude: location.longitud,
    );
  });
}

List<DistanceResult<FleetDriverLocationDto>> nearestDriversForLocation(
  LocationDto location,
  Iterable<FleetDriverLocationDto> drivers,
) {
  return _sortedDistances<FleetDriverLocationDto>(drivers, (driver) {
    return geodesicDistanceMeters(
      fromLatitude: location.latitud,
      fromLongitude: location.longitud,
      toLatitude: driver.latitude,
      toLongitude: driver.longitude,
    );
  });
}

List<DistanceResult<T>> _sortedDistances<T>(
  Iterable<T> values,
  double? Function(T value) distanceFor,
) {
  final result = <DistanceResult<T>>[];
  for (final value in values) {
    final meters = distanceFor(value);
    if (meters != null && meters.isFinite && meters >= 0) {
      result.add(DistanceResult(value: value, meters: meters));
    }
  }
  result.sort((a, b) => a.meters.compareTo(b.meters));
  return result;
}

IconData localMarkerIcon(String? key) => switch (key) {
  'store' => Icons.store,
  'storefront' => Icons.storefront,
  'business' => Icons.business,
  'grocery' => Icons.local_grocery_store,
  'shopping' => Icons.shopping_cart,
  'location' => Icons.location_on,
  _ => Icons.storefront,
};

Color localMarkerColor(String? value, Color fallback) {
  final color = value?.trim();
  if (color == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
    return fallback;
  }
  return Color(int.parse(color.substring(1), radix: 16) | 0xFF000000);
}
