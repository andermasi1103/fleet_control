import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../managements/data/dtos/management_dto.dart';
import '../dtos/available_order_dto.dart';

class DriverOrdersDataSource {
  DriverOrdersDataSource(this._client);

  final ApiClient _client;

  Future<List<AvailableOrderDto>> available(String token) async {
    final data = await _call('/api/driver/orders/available', token, 'GET');
    final orders = data['orders'];
    if (orders is! List) throw const FormatException('Respuesta inválida.');
    return orders
        .map(
          (item) => AvailableOrderDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<ManagementDto> claim(String token, String orderId) async {
    final data = await _call(
      '/api/driver/orders/$orderId/claim',
      token,
      'POST',
      body: const {},
    );
    final management = data['management'];
    if (management is! Map) throw const FormatException('Respuesta inválida.');
    return ManagementDto.fromJson(Map<String, dynamic>.from(management));
  }

  Future<Map<String, dynamic>> _call(
    String path,
    String token,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = method == 'GET'
          ? await _client.get<Map<String, dynamic>>(path, bearerToken: token)
          : await _client.post<Map<String, dynamic>>(
              path,
              bearerToken: token,
              data: body,
            );
      if (response.data is! Map) throw const FormatException();
      return Map<String, dynamic>.from(response.data as Map);
    } on ApiException catch (error) {
      final code = error.code;
      throw Failure(
        message: _message(error.statusCode, code),
        code: code,
        statusCode: error.statusCode,
        type: FailureType.backend,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.backend,
      );
    }
  }

  String _message(int? status, String? code) => switch (code) {
    'order_already_taken' => 'Este pedido ya fue tomado por otro chofer.',
    'driver_busy' => 'Ya tienes una gestión activa.',
    'driver_vehicle_required' =>
      'Necesitas un vehículo habitual asignado para tomar pedidos.',
    'vehicle_busy' => 'Tu vehículo habitual ya tiene una gestión activa.',
    _ => switch (status) {
      401 => 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      403 => 'No tienes permiso para realizar esta acción.',
      404 => 'El pedido ya no está disponible.',
      _ => 'No fue posible completar la operación.',
    },
  };
}
