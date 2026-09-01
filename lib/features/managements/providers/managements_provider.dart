import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../tracking/providers/driver_operational_state_provider.dart';
import '../data/datasources/managements_data_source.dart';
import '../data/dtos/management_dto.dart';

final managementsSourceProvider = Provider(
  (r) => ManagementsDataSource(r.watch(backendApiClientProvider)),
);
final managementsProvider =
    NotifierProvider<ManagementsNotifier, ManagementsState>(
      ManagementsNotifier.new,
    );

class ManagementsState {
  const ManagementsState({
    this.loading = false,
    this.saving = false,
    this.items = const [],
    this.drivers = const [],
    this.error,
  });
  final bool loading, saving;
  final List<ManagementDto> items;
  final List<DriverDto> drivers;
  final String? error;
  ManagementsState copyWith({
    bool? loading,
    bool? saving,
    List<ManagementDto>? items,
    List<DriverDto>? drivers,
    String? error,
    bool clearError = false,
  }) => ManagementsState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    items: items ?? this.items,
    drivers: drivers ?? this.drivers,
    error: clearError ? null : error ?? this.error,
  );
}

class ManagementsNotifier extends Notifier<ManagementsState> {
  @override
  ManagementsState build() => const ManagementsState();
  String? get t {
    final s = ref.read(sessionProvider).session;
    return s == null || s.isExpired ? null : s.sessionToken;
  }

  Future<void> load() async {
    if (t == null) return;
    state = state.copyWith(loading: true);
    try {
      state = state.copyWith(
        loading: false,
        items: await ref.read(managementsSourceProvider).list(t!),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'No fue posible cargar las gestiones.',
      );
    }
  }

  Future<void> drivers(String c) async {
    if (t != null) {
      state = state.copyWith(
        drivers: await ref.read(managementsSourceProvider).drivers(t!, c),
      );
    }
  }

  Future<bool> create(CreateManagementRequest r) async {
    if (t == null) return false;
    state = state.copyWith(saving: true);
    try {
      await ref.read(managementsSourceProvider).create(t!, r);
      await load();
      state = state.copyWith(saving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        saving: false,
        error: 'No fue posible asignar la gestión.',
      );
      return false;
    }
  }

  Future<bool> status(String id, String value) async {
    if (t == null) {
      state = state.copyWith(
        error: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return false;
    }
    state = state.copyWith(saving: true, clearError: true);
    try {
      final management = await ref
          .read(managementsSourceProvider)
          .status(t!, id, value);
      ref
          .read(driverOperationalStateProvider.notifier)
          .updateFromManagement(management);
      state = state.copyWith(saving: false);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(saving: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        saving: false,
        error: 'No fue posible actualizar la gestión.',
      );
      return false;
    }
  }

  Future<ManagementDto?> detail(String id) async {
    final token = t;
    if (token == null) return null;
    try {
      return await ref.read(managementsSourceProvider).detail(token, id);
    } on Failure catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }
}
