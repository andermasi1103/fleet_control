import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../attendance/data/dtos/location_dto.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/orders_data_source.dart';
import '../data/dtos/order_dto.dart';

final ordersDataSourceProvider = Provider(
  (ref) => OrdersDataSource(ref.watch(backendApiClientProvider)),
);
final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);

class OrdersState {
  const OrdersState({
    this.loading = false,
    this.creating = false,
    this.cancelling = false,
    this.orders = const [],
    this.locations = const [],
    this.descriptions = const [],
    this.locationsLoaded = false,
    this.locationsError,
    this.error,
  });
  final bool loading, creating, cancelling, locationsLoaded;
  final List<OrderDto> orders;
  final List<LocationDto> locations;
  final List<OrderDescriptionDto> descriptions;
  final String? locationsError;
  final String? error;
  OrdersState copyWith({
    bool? loading,
    bool? creating,
    bool? cancelling,
    List<OrderDto>? orders,
    List<LocationDto>? locations,
    List<OrderDescriptionDto>? descriptions,
    bool? locationsLoaded,
    String? locationsError,
    String? error,
    bool clearLocationsError = false,
    bool clearError = false,
  }) => OrdersState(
    loading: loading ?? this.loading,
    creating: creating ?? this.creating,
    cancelling: cancelling ?? this.cancelling,
    orders: orders ?? this.orders,
    locations: locations ?? this.locations,
    descriptions: descriptions ?? this.descriptions,
    locationsLoaded: locationsLoaded ?? this.locationsLoaded,
    locationsError: clearLocationsError
        ? null
        : locationsError ?? this.locationsError,
    error: clearError ? null : error ?? this.error,
  );
}

class OrdersNotifier extends Notifier<OrdersState> {
  @override
  OrdersState build() => const OrdersState();
  String? get _token {
    final s = ref.read(sessionProvider).session;
    return s == null || s.isExpired ? '' : s.sessionToken;
  }

  Future<void> load() async {
    final t = _token;
    if (t == null || t.isEmpty) {
      state = state.copyWith(
        error: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(
      loading: true,
      locationsLoaded: false,
      clearError: true,
      clearLocationsError: true,
    );
    final source = ref.read(ordersDataSourceProvider);
    final role = ref.read(sessionProvider).session?.user.role;
    List<OrderDto>? orders;
    List<LocationDto>? locations;
    Failure? ordersFailure;
    Failure? locationsFailure;

    await Future.wait<void>([
      () async {
        try {
          orders = await source.list(t);
        } on Failure catch (error) {
          ordersFailure = error;
        } catch (_) {
          ordersFailure = const Failure(
            message: 'No fue posible cargar los pedidos.',
            type: FailureType.backend,
          );
        }
      }(),
      () async {
        try {
          locations = await source.locations(
            t,
            administrative:
                role == 'super_admin' ||
                role == 'admin' ||
                role == 'supervisor',
          );
        } on Failure catch (error) {
          locationsFailure = error;
        } catch (_) {
          locationsFailure = const Failure(
            message: 'No fue posible cargar los locales.',
            type: FailureType.backend,
          );
        }
      }(),
    ]);

    final failure = locationsFailure ?? ordersFailure;
    state = state.copyWith(
      loading: false,
      orders: orders ?? const [],
      locations: locations ?? const [],
      locationsLoaded: locationsFailure == null,
      locationsError: locationsFailure?.message,
      error: failure?.message,
      clearLocationsError: locationsFailure == null,
      clearError: failure == null,
    );
  }

  Future<void> loadDescriptions(
    String companyId, {
    bool activeOnly = true,
  }) async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    state = state.copyWith(descriptions: const [], clearError: true);
    try {
      state = state.copyWith(
        descriptions: await ref
            .read(ordersDataSourceProvider)
            .descriptions(t, companyId, activeOnly: activeOnly),
      );
    } on Failure catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<bool> createDescription({
    required String companyId,
    required String name,
  }) async {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    try {
      await ref
          .read(ordersDataSourceProvider)
          .createDescription(t, companyId: companyId, name: name);
      await loadDescriptions(companyId, activeOnly: false);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> updateDescription({
    required String companyId,
    required String id,
    required String name,
    required bool isActive,
  }) async {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    try {
      await ref
          .read(ordersDataSourceProvider)
          .updateDescription(t, id: id, name: name, isActive: isActive);
      await loadDescriptions(companyId, activeOnly: false);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> create(CreateOrderRequest request) async {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    state = state.copyWith(creating: true, clearError: true);
    try {
      final order = await ref.read(ordersDataSourceProvider).create(t, request);
      state = state.copyWith(creating: false, orders: [order, ...state.orders]);
      return true;
    } on Failure catch (e) {
      state = state.copyWith(creating: false, error: e.message);
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    final t = _token;
    if (t == null || t.isEmpty) return false;
    state = state.copyWith(cancelling: true, clearError: true);
    try {
      final updated = await ref.read(ordersDataSourceProvider).cancel(t, id);
      state = state.copyWith(
        cancelling: false,
        orders: [
          for (final x in state.orders)
            if (x.id == id) updated else x,
        ],
      );
      return true;
    } on Failure catch (e) {
      state = state.copyWith(cancelling: false, error: e.message);
      return false;
    }
  }

  Future<OrderDto?> detail(String id) async {
    final t = _token;
    if (t == null || t.isEmpty) return null;
    try {
      return await ref.read(ordersDataSourceProvider).detail(t, id);
    } on Failure catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }
}
