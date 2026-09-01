import 'tracking_profile.dart';

/// The backend management status represented for the authenticated driver.
enum DriverOperationalState {
  available,
  assigned,
  accepted,
  enRoute,
  inProgress,
}

DriverOperationalState driverOperationalStateFromManagementStatus(
  String managementStatus,
) {
  return switch (managementStatus) {
    'asignado' => DriverOperationalState.assigned,
    'aceptado' => DriverOperationalState.accepted,
    'en_camino' => DriverOperationalState.enRoute,
    'en_gestion' => DriverOperationalState.inProgress,
    _ => DriverOperationalState.available,
  };
}

DriverOperationalState driverOperationalStateFromManagementStatuses(
  Iterable<String> managementStatuses,
) {
  final states = managementStatuses
      .map(driverOperationalStateFromManagementStatus)
      .toSet();

  for (final state in const [
    DriverOperationalState.inProgress,
    DriverOperationalState.enRoute,
    DriverOperationalState.accepted,
    DriverOperationalState.assigned,
  ]) {
    if (states.contains(state)) return state;
  }

  return DriverOperationalState.available;
}

TrackingProfile trackingProfileForOperationalState(
  DriverOperationalState? operationalState,
) {
  return switch (operationalState) {
    null => TrackingProfile.idle,
    DriverOperationalState.available ||
    DriverOperationalState.assigned => TrackingProfile.available,
    DriverOperationalState.accepted ||
    DriverOperationalState.enRoute ||
    DriverOperationalState.inProgress => TrackingProfile.activeTrip,
  };
}
