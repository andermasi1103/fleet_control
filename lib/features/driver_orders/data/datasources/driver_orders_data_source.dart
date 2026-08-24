import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../../../managements/data/dtos/management_dto.dart';
import '../dtos/available_order_dto.dart';

class DriverOrdersDataSource {
  DriverOrdersDataSource(this._client);

  final SupabaseClient _client;

  Future<List<AvailableOrderDto>> available(String token) async {
    final data = await _call('driver-orders-available', token, HttpMethod.get);
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
      'driver-order-claim',
      token,
      HttpMethod.post,
      body: {'order_id': orderId},
    );
    final management = data['management'];
    if (management is! Map) throw const FormatException('Respuesta inválida.');
    return ManagementDto.fromJson(Map<String, dynamic>.from(management));
  }

  Future<Map<String, dynamic>> _call(
    String name,
    String token,
    HttpMethod method, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.functions.invoke(
        name,
        method: method,
        headers: {'Authorization': 'Bearer $token'},
        body: body,
      );
      if (response.data is! Map) throw const FormatException();
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final code = _backendCode(error.details);
      throw Failure(
        message: _message(error.status, code),
        code: code,
        statusCode: error.status,
        type: FailureType.supabase,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.supabase,
      );
    }
  }

  String? _backendCode(Object? value) {
    dynamic body = value;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is Map && body['error'] is String) return body['error'] as String;
    return null;
  }

  String _message(int status, String? code) => switch (code) {
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
