import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../managements/data/dtos/management_dto.dart';
import '../data/datasources/driver_orders_data_source.dart';
import '../data/dtos/available_order_dto.dart';

final driverOrdersDataSourceProvider = Provider(
  (ref) => DriverOrdersDataSource(ref.watch(supabaseClientProvider)),
);

final driverOrdersProvider =
    NotifierProvider<DriverOrdersNotifier, DriverOrdersState>(
      DriverOrdersNotifier.new,
    );

class DriverOrdersState {
  const DriverOrdersState({
    this.loading = false,
    this.claiming = false,
    this.orders = const [],
    this.error,
    this.errorCode,
  });

  final bool loading;
  final bool claiming;
  final List<AvailableOrderDto> orders;
  final String? error;
  final String? errorCode;

  DriverOrdersState copyWith({
    bool? loading,
    bool? claiming,
    List<AvailableOrderDto>? orders,
    String? error,
    String? errorCode,
    bool clearError = false,
  }) => DriverOrdersState(
    loading: loading ?? this.loading,
    claiming: claiming ?? this.claiming,
    orders: orders ?? this.orders,
    error: clearError ? null : error ?? this.error,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );
}

class DriverOrdersNotifier extends Notifier<DriverOrdersState> {
  @override
  DriverOrdersState build() => const DriverOrdersState();

  String? get _token {
    final session = ref.read(sessionProvider).session;
    return session == null || session.isExpired ? null : session.sessionToken;
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(
        error: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
        errorCode: 'unauthorized',
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final orders = await ref.read(driverOrdersDataSourceProvider).available(
            token,
          );
      state = state.copyWith(loading: false, orders: orders);
    } on Failure catch (error) {
      state = state.copyWith(
        loading: false,
        error: error.message,
        errorCode: error.code,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'No fue posible cargar los pedidos disponibles.',
      );
    }
  }

  Future<ManagementDto?> claim(String orderId) async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(
        error: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
        errorCode: 'unauthorized',
      );
      return null;
    }
    state = state.copyWith(claiming: true, clearError: true);
    try {
      final management = await ref
          .read(driverOrdersDataSourceProvider)
          .claim(token, orderId);
      state = state.copyWith(
        claiming: false,
        orders: state.orders.where((order) => order.id != orderId).toList(),
      );
      return management;
    } on Failure catch (error) {
      state = state.copyWith(
        claiming: false,
        error: error.message,
        errorCode: error.code,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        claiming: false,
        error: 'No fue posible tomar el pedido.',
      );
      return null;
    }
  }
}
