import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failure.dart';
import '../dtos/management_dto.dart';

class ManagementsDataSource {
  ManagementsDataSource(this.c);
  final SupabaseClient c;
  Future<Map<String, dynamic>> _call(
    String n,
    String t,
    HttpMethod m, {
    Object? body,
    Map<String, String>? q,
  }) async {
    try {
      final r = await c.functions.invoke(
        n,
        method: m,
        headers: {'Authorization': 'Bearer $t'},
        body: body,
        queryParameters: q,
      );
      if (kDebugMode && n == 'managements-update-status') {
        debugPrint(
          'management-update response: '
          'statusCode=${r.status} code=${_backendCode(r.data) ?? 'none'}',
        );
      }
      return Map<String, dynamic>.from(r.data as Map);
    } on FunctionException catch (e) {
      final backendCode = _backendCode(e.details);
      if (kDebugMode && n == 'managements-update-status') {
        debugPrint(
          'management-update response: '
          'statusCode=${e.status} code=${backendCode ?? 'none'}',
        );
      }
      throw Failure(
        message: switch (backendCode) {
          'active_management_exists' =>
            'Ya tienes otra gestión activa. Complétala antes de iniciar la siguiente.',
          _ => switch (e.status) {
            401 => 'Tu sesión ha vencido. Inicia sesión nuevamente.',
            403 => 'No tienes permiso para realizar esta acción.',
            409 => 'No se puede realizar ese cambio de estado.',
            404 => 'La gestión ya no está disponible.',
            500 => 'No fue posible actualizar la gestión.',
            _ => 'No fue posible completar la operación.',
          },
        },
        code: backendCode ?? (e.status == 404 ? 'not_found' : null),
        statusCode: e.status,
        type: FailureType.supabase,
      );
    }
  }

  String? _backendCode(Object? value) {
    dynamic data = value;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    if (data is Map) {
      final code = data['error'] ?? data['code'];
      return code is String ? code : null;
    }
    return null;
  }

  Future<List<ManagementDto>> list(String t, {String? orderId}) =>
      _call(
        'managements-list',
        t,
        HttpMethod.get,
        q: {'limit': '50', 'offset': '0', 'order_id': ?orderId},
      ).then(
        (x) => (x['managements'] as List)
            .map((e) => ManagementDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Future<ManagementDto> detail(String t, String id) =>
      _call('managements-detail', t, HttpMethod.get, q: {'id': id}).then(
        (x) => ManagementDto.fromJson(
          Map<String, dynamic>.from(x['management'])..['events'] = x['events'],
        ),
      );
  Future<List<DriverDto>> drivers(String t, String company) =>
      _call('drivers-list', t, HttpMethod.get, q: {'empresa_id': company}).then(
        (x) => (x['drivers'] as List)
            .map((e) => DriverDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
  Future<ManagementDto> create(String t, CreateManagementRequest r) =>
      _call('managements-create', t, HttpMethod.post, body: r.toJson()).then(
        (x) =>
            ManagementDto.fromJson(Map<String, dynamic>.from(x['management'])),
      );
  Future<ManagementDto> status(String t, String id, String s) {
    if (kDebugMode) {
      debugPrint('management-update request: managementId=$id status=$s');
    }
    return _call(
      'managements-update-status',
      t,
      HttpMethod.post,
      body: {'management_id': id, 'status': s},
    ).then(
      (x) => ManagementDto.fromJson(Map<String, dynamic>.from(x['management'])),
    );
  }
}
