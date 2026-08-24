import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/location_service.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/attendance_data_source.dart';
import '../data/dtos/attendance_status_dto.dart';
import '../data/dtos/location_dto.dart';
import 'attendance_state.dart';

final attendanceDataSourceProvider = Provider<AttendanceDataSource>((ref) {
  return AttendanceDataSource(ref.watch(supabaseClientProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() => const AttendanceState();

  Future<void> initialize() async {
    if (state.isInitializing) {
      return;
    }
    final token = _sessionToken();
    if (token == null) {
      state = const AttendanceState(
        actionErrorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }

    state = const AttendanceState(
      isInitializing: true,
      isLoadingLocation: true,
    );
    final dataSource = ref.read(attendanceDataSourceProvider);
    final locationsRequest = dataSource.getLocations(sessionToken: token);
    final statusRequest = dataSource.getAttendanceStatus(sessionToken: token);
    final positionRequest = ref
        .read(locationServiceProvider)
        .getCurrentPosition();

    List<LocationDto> locations = const [];
    AttendanceStatusDto? status;
    Position? position;
    String? locationsError;
    String? statusError;
    String? locationError;

    try {
      locations = (await locationsRequest)
          .where((location) => location.isActive)
          .toList(growable: false);
    } on Failure catch (error) {
      locationsError = error.message;
    } catch (_) {
      locationsError = 'No fue posible cargar los locales.';
    }

    try {
      status = await statusRequest;
    } on Failure catch (error) {
      statusError = error.message;
    } catch (_) {
      statusError = 'No fue posible cargar el estado de asistencia.';
    }

    try {
      position = await positionRequest;
    } on LocationServiceException catch (error) {
      locationError = _locationMessage(error.error);
    } catch (_) {
      locationError = 'Error obteniendo ubicación.';
    }

    final selected = position == null
        ? (locations.isEmpty ? null : locations.first)
        : _nearestLocation(locations, position);
    state = AttendanceState(
      locations: locations,
      selectedLocation: selected,
      position: position,
      distanceMeters: _distanceTo(selected, position),
      status: status,
      locationsErrorMessage: locationsError,
      statusErrorMessage: statusError,
      locationErrorMessage: locationError,
    );
  }

  Future<void> refreshLocation() async {
    if (state.isLoadingLocation || state.isMarking) {
      return;
    }
    state = state.copyWith(isLoadingLocation: true, clearLocationError: true);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      final selected =
          _nearestLocation(state.locations, position) ?? state.selectedLocation;
      state = AttendanceState(
        locations: state.locations,
        selectedLocation: selected,
        position: position,
        distanceMeters: _distanceTo(selected, position),
        status: state.status,
        lastAttendance: state.lastAttendance,
        locationsErrorMessage: state.locationsErrorMessage,
        statusErrorMessage: state.statusErrorMessage,
        actionErrorMessage: state.actionErrorMessage,
        successMessage: state.successMessage,
      );
    } on LocationServiceException catch (error) {
      state = state.copyWith(
        isLoadingLocation: false,
        locationErrorMessage: _locationMessage(error.error),
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingLocation: false,
        locationErrorMessage: 'Error obteniendo ubicación.',
      );
    }
  }

  void selectLocation(String locationId) {
    final matching = state.locations.where((item) => item.id == locationId);
    if (matching.isEmpty) {
      return;
    }
    final selected = matching.first;
    state = state.copyWith(
      selectedLocation: selected,
      distanceMeters: _distanceTo(selected, state.position),
      clearActionError: true,
    );
  }

  Future<bool> markAttendance() async {
    if (state.isMarking) {
      return false;
    }
    final token = _sessionToken();
    final location = state.selectedLocation;
    final position = state.position;
    final nextAction = state.status?.nextAction;
    if (token == null) {
      state = state.copyWith(
        actionErrorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
        clearSuccess: true,
      );
      return false;
    }
    if (location == null || position == null || nextAction == null) {
      state = state.copyWith(
        actionErrorMessage: state.markUnavailableReason,
        clearSuccess: true,
      );
      return false;
    }
    if (state.isWithinGeofence != true) {
      state = state.copyWith(
        actionErrorMessage:
            'Estás fuera de la geocerca permitida para este local.',
        clearSuccess: true,
      );
      return false;
    }

    state = state.copyWith(
      isMarking: true,
      clearActionError: true,
      clearSuccess: true,
    );
    try {
      final dataSource = ref.read(attendanceDataSourceProvider);
      final attendance = await dataSource.createAttendance(
        sessionToken: token,
        localId: location.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final updatedStatus = await dataSource.getAttendanceStatus(
        sessionToken: token,
      );
      state = AttendanceState(
        locations: state.locations,
        selectedLocation: location,
        position: position,
        distanceMeters: _distanceTo(location, position),
        status: updatedStatus,
        lastAttendance: attendance,
        locationsErrorMessage: state.locationsErrorMessage,
        statusErrorMessage: state.statusErrorMessage,
        locationErrorMessage: state.locationErrorMessage,
        successMessage: nextAction == 'entrada'
            ? 'Entrada registrada correctamente.'
            : 'Salida registrada correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(
        isMarking: false,
        actionErrorMessage: error.message,
        clearSuccess: true,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isMarking: false,
        actionErrorMessage:
            'No fue posible registrar la asistencia. Intenta nuevamente.',
        clearSuccess: true,
      );
      return false;
    }
  }

  String? _sessionToken() {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      return null;
    }
    return session.sessionToken;
  }

  LocationDto? _nearestLocation(
    List<LocationDto> locations,
    Position position,
  ) {
    if (locations.isEmpty) {
      return null;
    }
    return locations.reduce((nearest, candidate) {
      final nearestDistance = _distanceTo(nearest, position)!;
      final candidateDistance = _distanceTo(candidate, position)!;
      return candidateDistance < nearestDistance ? candidate : nearest;
    });
  }

  double? _distanceTo(LocationDto? location, Position? position) {
    if (location == null || position == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitud,
      location.longitud,
    );
  }

  String _locationMessage(LocationServiceError error) {
    switch (error) {
      case LocationServiceError.disabled:
        return 'GPS desactivado. Activa los servicios de ubicación para registrar asistencia.';
      case LocationServiceError.denied:
        return 'Permiso requerido para obtener tu ubicación.';
      case LocationServiceError.deniedForever:
        return 'El permiso de ubicación está bloqueado. Habilítalo desde la configuración del dispositivo o navegador.';
      case LocationServiceError.unavailable:
        return 'Error obteniendo ubicación.';
    }
  }
}
