import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_control/core/network/api_client.dart';
import 'package:fleet_control/features/fleet_tracking/data/datasources/fleet_locations_data_source.dart';
import 'package:fleet_control/features/reports/data/reports_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fleet map usa Fastify, Bearer y conserva el contrato de marcadores',
    () async {
      final adapter = _Adapter(
        body: {
          'drivers': [
            {
              'driver_user_id': 'driver-1',
              'driver_name': 'Chofer',
              'driver_username': 'chofer',
              'connection_status': 'online',
              'operational_status': 'aceptado',
              'vehicle_plate': 'ABC123',
              'vehicle_type': 'moto',
              'latitude': -25.2,
              'longitude': -57.6,
              'captured_at': '2030-01-01T00:00:00.000Z',
              'last_seen_at': '2030-01-01T00:01:00.000Z',
            },
          ],
        },
      );
      final drivers = await FleetLocationsDataSource(
        _api(adapter),
      ).list(sessionToken: 'token');
      expect(adapter.request?.path, '/api/fleet/locations');
      expect(adapter.request?.headers['Authorization'], 'Bearer token');
      expect(drivers.single.connectionStatus, 'online');
      expect(drivers.single.operationalStatus, 'aceptado');
      expect(drivers.single.vehiclePlate, 'ABC123');
      expect(drivers.single.capturedAt, isNotNull);
      expect(drivers.single.lastSeenAt, isNotNull);
    },
  );

  test(
    'reports usa la ruta tipada Fastify y conserva filas simplificadas',
    () async {
      final adapter = _Adapter(
        body: {
          'type': 'orders',
          'rows': [
            {
              'Fecha': '2030-01-01T00:00:00.000Z',
              'Local': 'Central',
              'Estado': 'pendiente',
            },
          ],
          'count': 1,
        },
      );
      final report = await ReportsDataSource(
        _api(adapter),
      ).load(token: 'token', type: ReportType.orders);
      expect(adapter.request?.path, '/api/reports/orders');
      expect(adapter.request?.headers['Authorization'], 'Bearer token');
      expect(report.rows.single.keys, isNot(contains('pedido_id')));
    },
  );
}

ApiClient _api(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio);
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.body});
  final Object body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
