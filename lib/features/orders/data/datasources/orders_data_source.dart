import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../../../attendance/data/dtos/location_dto.dart';
import '../dtos/order_dto.dart';

class OrdersDataSource {
  OrdersDataSource(this._client);
  final SupabaseClient _client;
  Future<Map<String, dynamic>> _call(
    String name,
    String token,
    HttpMethod method, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      final response = await _client.functions.invoke(
        name,
        method: method,
        headers: {'Authorization': 'Bearer $token'},
        body: body,
        queryParameters: query,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw _failure(e.status);
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  Future<List<OrderDto>> list(String token) async {
    final data = await _call(
      'orders-list',
      token,
      HttpMethod.get,
      query: {'limit': '50', 'offset': '0'},
    );
    return (data['orders'] as List)
        .map((e) => OrderDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OrderDto> detail(String token, String id) async {
    final data = await _call(
      'orders-detail',
      token,
      HttpMethod.get,
      query: {'id': id},
    );
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<OrderDto> create(String token, CreateOrderRequest request) async {
    final data = await _call(
      'orders-create',
      token,
      HttpMethod.post,
      body: request.toJson(),
    );
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<OrderDto> cancel(String token, String id) async {
    final data = await _call(
      'orders-cancel',
      token,
      HttpMethod.post,
      body: {'order_id': id},
    );
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<List<LocationDto>> locations(
    String token, {
    required bool administrative,
  }) async {
    final data = await _call(
      administrative ? 'locations-list' : 'my-locations-list',
      token,
      HttpMethod.get,
    );
    return (data['locations'] as List)
        .map((e) => LocationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((x) => x.isActive)
        .toList();
  }

  Future<List<OrderDescriptionDto>> descriptions(
    String token,
    String companyId, {
    bool activeOnly = true,
  }) async {
    final data = await _call(
      'order-descriptions-list',
      token,
      HttpMethod.get,
      query: {'empresa_id': companyId},
    );
    return (data['descriptions'] as List)
        .map(
          (e) =>
              OrderDescriptionDto.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .where((x) => !activeOnly || x.isActive)
        .toList();
  }

  Future<OrderDescriptionDto> createDescription(
    String token, {
    required String companyId,
    required String name,
  }) async {
    final data = await _call(
      'order-descriptions-create',
      token,
      HttpMethod.post,
      body: {'empresa_id': companyId, 'nombre': name},
    );
    return OrderDescriptionDto.fromJson(
      Map<String, dynamic>.from(data['description'] as Map),
    );
  }

  Future<OrderDescriptionDto> updateDescription(
    String token, {
    required String id,
    required String name,
    required bool isActive,
  }) async {
    final data = await _call(
      'order-descriptions-update',
      token,
      HttpMethod.patch,
      body: {'id': id, 'nombre': name, 'activo': isActive},
    );
    return OrderDescriptionDto.fromJson(
      Map<String, dynamic>.from(data['description'] as Map),
    );
  }

  Failure _failure(int status) => switch (status) {
    400 => const Failure(
      message: 'Revisa los datos ingresados.',
      type: FailureType.supabase,
    ),
    401 => const Failure(
      message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      type: FailureType.sessionExpired,
    ),
    403 => const Failure(
      message: 'No tienes permiso para realizar esta acción.',
      type: FailureType.insufficientPermissions,
    ),
    404 => const Failure(
      message: 'El pedido ya no está disponible.',
      code: 'not_found',
      type: FailureType.supabase,
    ),
    409 => const Failure(
      message: 'El pedido ya no puede cancelarse.',
      type: FailureType.supabase,
    ),
    _ => const Failure(
      message: 'No fue posible completar la operación.',
      type: FailureType.supabase,
    ),
  };
}
