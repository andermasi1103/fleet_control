import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../attendance/data/dtos/location_dto.dart';
import '../dtos/order_dto.dart';

class OrdersDataSource {
  OrdersDataSource(this._client);
  final ApiClient _client;
  Future<Map<String, dynamic>> _call(
    String path,
    String token,
    String method, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    try {
      final response = switch (method) {
        'GET' => await _client.get<Map<String, dynamic>>(
          path,
          bearerToken: token,
          queryParameters: query,
        ),
        'POST' => await _client.post<Map<String, dynamic>>(
          path,
          bearerToken: token,
          data: body,
          queryParameters: query,
        ),
        'PATCH' => await _client.patch<Map<String, dynamic>>(
          path,
          bearerToken: token,
          data: body,
          queryParameters: query,
        ),
        _ => throw StateError('Método no soportado.'),
      };
      return Map<String, dynamic>.from(response.data ?? const {});
    } on ApiException catch (e) {
      throw _failure(e.statusCode);
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.backend,
      );
    }
  }

  Future<List<OrderDto>> list(String token) async {
    final data = await _call(
      '/api/orders',
      token,
      'GET',
      query: {'limit': '50', 'offset': '0'},
    );
    return (data['orders'] as List)
        .map((e) => OrderDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OrderDto> detail(String token, String id) async {
    final data = await _call('/api/orders/$id', token, 'GET');
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<OrderDto> create(String token, CreateOrderRequest request) async {
    final data = await _call(
      '/api/orders',
      token,
      'POST',
      body: request.toJson(),
    );
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<OrderDto> cancel(String token, String id) async {
    final data = await _call(
      '/api/orders/$id/cancel',
      token,
      'POST',
      body: const {},
    );
    return OrderDto.fromJson(Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<List<LocationDto>> locations(
    String token, {
    required bool administrative,
  }) async {
    final data = await _call(
      administrative ? '/api/locations' : '/api/me/locations',
      token,
      'GET',
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
      '/api/order-descriptions',
      token,
      'GET',
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
      '/api/order-descriptions',
      token,
      'POST',
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
      '/api/order-descriptions/$id',
      token,
      'PATCH',
      body: {'nombre': name, 'activo': isActive},
    );
    return OrderDescriptionDto.fromJson(
      Map<String, dynamic>.from(data['description'] as Map),
    );
  }

  Failure _failure(int? status) => switch (status) {
    400 => const Failure(
      message: 'Revisa los datos ingresados.',
      type: FailureType.backend,
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
      type: FailureType.backend,
    ),
    409 => const Failure(
      message: 'El pedido ya no puede cancelarse.',
      type: FailureType.backend,
    ),
    _ => const Failure(
      message: 'No fue posible completar la operación.',
      type: FailureType.backend,
    ),
  };
}
