import 'package:geolocator/geolocator.dart';

import '../data/dtos/attendance_dto.dart';
import '../data/dtos/attendance_status_dto.dart';
import '../data/dtos/location_dto.dart';

class AttendanceState {
  const AttendanceState({
    this.isInitializing = false,
    this.isLoadingLocation = false,
    this.isMarking = false,
    this.locations = const [],
    this.selectedLocation,
    this.position,
    this.distanceMeters,
    this.status,
    this.lastAttendance,
    this.locationsErrorMessage,
    this.statusErrorMessage,
    this.locationErrorMessage,
    this.actionErrorMessage,
    this.successMessage,
  });

  final bool isInitializing;
  final bool isLoadingLocation;
  final bool isMarking;
  final List<LocationDto> locations;
  final LocationDto? selectedLocation;
  final Position? position;
  final double? distanceMeters;
  final AttendanceStatusDto? status;
  final AttendanceDto? lastAttendance;
  final String? locationsErrorMessage;
  final String? statusErrorMessage;
  final String? locationErrorMessage;
  final String? actionErrorMessage;
  final String? successMessage;

  bool get isLoading => isInitializing || isLoadingLocation;

  bool? get isWithinGeofence {
    final location = selectedLocation;
    final distance = distanceMeters;
    if (location == null || distance == null) {
      return null;
    }
    return distance <= location.radioMetros;
  }

  String? get markUnavailableReason {
    if (selectedLocation == null) {
      return 'No hay un local seleccionado.';
    }
    if (position == null) {
      return 'Esperando ubicación GPS.';
    }
    if (status == null) {
      return 'No se pudo determinar si corresponde entrada o salida.';
    }
    if (isWithinGeofence == false) {
      return 'Estás fuera de la geocerca permitida.';
    }
    return null;
  }

  AttendanceState copyWith({
    bool? isInitializing,
    bool? isLoadingLocation,
    bool? isMarking,
    List<LocationDto>? locations,
    LocationDto? selectedLocation,
    Position? position,
    double? distanceMeters,
    AttendanceStatusDto? status,
    AttendanceDto? lastAttendance,
    String? locationsErrorMessage,
    String? statusErrorMessage,
    String? locationErrorMessage,
    String? actionErrorMessage,
    String? successMessage,
    bool clearLocationsError = false,
    bool clearStatusError = false,
    bool clearLocationError = false,
    bool clearActionError = false,
    bool clearSuccess = false,
  }) {
    return AttendanceState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isMarking: isMarking ?? this.isMarking,
      locations: locations ?? this.locations,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      position: position ?? this.position,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      status: status ?? this.status,
      lastAttendance: lastAttendance ?? this.lastAttendance,
      locationsErrorMessage: clearLocationsError
          ? null
          : locationsErrorMessage ?? this.locationsErrorMessage,
      statusErrorMessage: clearStatusError
          ? null
          : statusErrorMessage ?? this.statusErrorMessage,
      locationErrorMessage: clearLocationError
          ? null
          : locationErrorMessage ?? this.locationErrorMessage,
      actionErrorMessage: clearActionError
          ? null
          : actionErrorMessage ?? this.actionErrorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
