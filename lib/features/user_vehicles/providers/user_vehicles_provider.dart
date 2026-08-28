import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/user_vehicles_data_source.dart';
import '../data/dtos/user_vehicle_dto.dart';

final userVehiclesDataSourceProvider = Provider<UserVehiclesDataSource>((ref) {
  return UserVehiclesDataSource(ref.watch(backendApiClientProvider));
});

final userVehicleProvider =
    NotifierProvider<UserVehicleNotifier, UserVehicleState>(
      UserVehicleNotifier.new,
    );

class UserVehicleState {
  const UserVehicleState({
    this.isLoading = false,
    this.isSaving = false,
    this.assignment,
    this.vehicles = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final UserVehicleDto? assignment;
  final List<UserVehicleOptionDto> vehicles;
  final String? errorMessage;

  UserVehicleState copyWith({
    bool? isLoading,
    bool? isSaving,
    UserVehicleDto? assignment,
    List<UserVehicleOptionDto>? vehicles,
    String? errorMessage,
    bool clearAssignment = false,
    bool clearError = false,
  }) {
    return UserVehicleState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      assignment: clearAssignment ? null : assignment ?? this.assignment,
      vehicles: vehicles ?? this.vehicles,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class UserVehicleNotifier extends Notifier<UserVehicleState> {
  @override
  UserVehicleState build() => const UserVehicleState();

  Future<bool> load(String userId) async {
    final token = _token();
    if (token == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final lookup = await ref
          .read(userVehiclesDataSourceProvider)
          .get(sessionToken: token, userId: userId);
      state = UserVehicleState(
        assignment: lookup.assignment,
        vehicles: lookup.vehicles,
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar el vehículo habitual.',
      );
      return false;
    }
  }

  Future<bool> update(String userId, String? vehicleId) async {
    final token = _token();
    if (token == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(userVehiclesDataSourceProvider)
          .update(sessionToken: token, userId: userId, vehicleId: vehicleId);
      return await load(userId);
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible actualizar el vehículo habitual.',
      );
      return false;
    }
  }

  String? _token() {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return null;
    }
    return session.sessionToken;
  }
}
