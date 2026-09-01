import 'dart:math' as math;

import '../data/dtos/fleet_driver_location_dto.dart';

enum FleetMapVisualState { available, active, offline }

FleetMapVisualState fleetMapVisualState(FleetDriverLocationDto driver) {
  if (driver.connectionStatus != 'online') return FleetMapVisualState.offline;
  return switch (driver.operationalStatus) {
    'aceptado' || 'en_camino' || 'en_gestion' => FleetMapVisualState.active,
    _ => FleetMapVisualState.available,
  };
}

double headingRadians(double? heading) {
  if (heading == null || !heading.isFinite || heading < 0 || heading > 360) {
    return 0;
  }
  return heading * math.pi / 180;
}

String speedLabel(double? metersPerSecond) {
  if (metersPerSecond == null || !metersPerSecond.isFinite) {
    return 'Velocidad no disponible';
  }
  return '${(math.max(0, metersPerSecond) * 3.6).round()} km/h';
}

String accuracyLabel(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) {
    return 'Precisión no disponible';
  }
  return 'Precisión ±${meters.round()} m';
}

String relativeTimeLabel(DateTime? value, {required DateTime now}) {
  if (value == null) return 'Sin datos';
  final elapsed = now.difference(value);
  if (elapsed <= const Duration(seconds: 5)) return 'ahora';
  if (elapsed.inSeconds < 60) return 'hace ${elapsed.inSeconds} s';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
  return 'hace ${elapsed.inDays} d';
}

bool isStalePosition(DateTime? capturedAt, {required DateTime now}) {
  if (capturedAt == null) return false;
  return now.difference(capturedAt) > const Duration(minutes: 2);
}

bool hasDrawableAccuracy(double? accuracy) =>
    accuracy != null && accuracy.isFinite && accuracy >= 0 && accuracy <= 500;
