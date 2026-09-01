import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_control/core/errors/failure.dart';
import 'package:fleet_control/core/network/api_client.dart';
import 'package:fleet_control/features/companies/data/datasources/companies_data_source.dart';
import 'package:fleet_control/features/locations/data/datasources/locations_data_source.dart';
import 'package:fleet_control/features/locations/data/dtos/location_import_dto.dart';
import 'package:fleet_control/features/role_views/data/datasources/role_views_data_source.dart';
import 'package:fleet_control/features/user_vehicles/data/datasources/user_vehicles_data_source.dart';
import 'package:fleet_control/features/users/data/datasources/users_data_source.dart';
import 'package:fleet_control/features/users/data/supervisor_drivers_data_source.dart';
import 'package:fleet_control/features/vehicles/data/datasources/vehicles_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('companies usa Fastify, Bearer y mapea 409', () async {
    final adapter = _Adapter(body: {'company': _company()});
    final source = CompaniesDataSource(_api(adapter));
    await source.createCompany(sessionToken: 'token', nombre: 'Acme');
    expect(adapter.request?.path, '/api/companies');
    expect(adapter.request?.headers['Authorization'], 'Bearer token');

    await expectLater(
      CompaniesDataSource(
        _api(_Adapter(status: 409, body: {'error': 'conflict'})),
      ).createCompany(sessionToken: 'token', nombre: 'Acme'),
      throwsA(
        isA<Failure>().having(
          (error) => error.message,
          'message',
          contains('Ya existe'),
        ),
      ),
    );
  });

  test('locations e import conservan payload Fastify', () async {
    final create = _Adapter(body: {'location': _location()});
    await LocationsDataSource(_api(create)).createLocation(
      sessionToken: 'token',
      companyId: 'company-1',
      nombre: 'Local',
      direccion: null,
      latitude: -25.2,
      longitude: -57.6,
      radioMeters: 100,
    );
    expect(create.request?.path, '/api/locations');
    expect(create.request?.data['empresa_id'], 'company-1');

    final import = _Adapter(body: {'imported_count': 1});
    await LocationsDataSource(_api(import)).importLocations(
      sessionToken: 'token',
      companyId: 'company-1',
      locations: [
        const LocationImportRow(
          rowNumber: 1,
          codigo: 'L01',
          nombre: 'Local',
          descripcion: null,
          direccion: null,
          latitud: -25.2,
          longitud: -57.6,
          radioGeocercaMetros: 100,
          activo: true,
        ),
      ],
    );
    expect(import.request?.path, '/api/locations/import');
    expect(import.request?.headers['Authorization'], 'Bearer token');
  });

  test('el mapa omite locales inválidos sin ocultar locales válidos', () async {
    final invalid = {..._location(), 'id': 'invalid', 'latitud': 91};
    final source = LocationsDataSource(
      _api(
        _Adapter(
          body: {
            'locations': [_location(), invalid],
          },
        ),
      ),
    );

    final locations = await source.getMapLocations(sessionToken: 'token');

    expect(locations, hasLength(1));
    expect(locations.single.id, 'location-1');
  });

  test('users, roles y user-locations usan rutas REST', () async {
    final roles = _Adapter(
      body: {
        'roles': [
          {'id': 'role-1', 'codigo': 'admin'},
        ],
      },
    );
    await UsersDataSource(_api(roles)).getRoles(sessionToken: 'token');
    expect(roles.request?.path, '/api/roles');

    final locations = _Adapter(
      body: {
        'locations': [
          {
            'id': 'location-1',
            'empresa_id': 'company-1',
            'nombre': 'Local',
            'activo': true,
            'assigned': false,
          },
        ],
      },
    );
    await UsersDataSource(
      _api(locations),
    ).getUserLocations(sessionToken: 'token', userId: 'user-1');
    expect(locations.request?.path, '/api/users/user-1/locations');

    final reset = _Adapter(body: {'success': true});
    await UsersDataSource(_api(reset)).resetPassword(
      sessionToken: 'token',
      userId: 'user-1',
      password: 'clave-segura',
    );
    expect(reset.request?.path, '/api/users/user-1/password-reset');
    expect(reset.request?.data, {'password': 'clave-segura'});
  });

  test(
    'vehicles y vehículo habitual usan Bearer y paths por usuario',
    () async {
      final vehicle = _Adapter(body: {'vehicle': _vehicle()});
      await VehiclesDataSource(_api(vehicle)).createVehicle(
        sessionToken: 'token',
        companyId: 'company-1',
        plate: 'ABC123',
      );
      expect(vehicle.request?.path, '/api/vehicles');

      final habitual = _Adapter(
        body: {
          'user_vehicle': null,
          'vehicles': [_vehicle()],
        },
      );
      await UserVehiclesDataSource(
        _api(habitual),
      ).get(sessionToken: 'token', userId: 'driver-1');
      expect(habitual.request?.path, '/api/users/driver-1/vehicle');
    },
  );

  test(
    'supervisor drivers y role views usan las rutas administrativas',
    () async {
      final drivers = _Adapter(
        body: {
          'available_drivers': [
            {
              'id': 'driver-2',
              'usuario': 'chofer-disponible',
              'nombre': 'Chofer disponible',
            },
          ],
          'assigned_drivers': [
            {
              'id': 'driver-1',
              'usuario': 'chofer-asignado',
              'nombre': 'Chofer asignado',
            },
          ],
          'assigned_driver_ids': ['driver-1'],
        },
      );
      final supervisorDrivers = await SupervisorDriversDataSource(
        _api(drivers),
      ).load('token', 'supervisor-1');
      expect(drivers.request?.path, '/api/supervisors/supervisor-1/drivers');
      expect(supervisorDrivers.drivers.map((driver) => driver.id), {
        'driver-1',
        'driver-2',
      });
      expect(supervisorDrivers.assignedIds, {'driver-1'});

      final matrix = _Adapter(
        body: {
          'roles': [
            {'codigo': 'admin'},
          ],
          'views': [
            {'codigo': 'home', 'nombre': 'Inicio', 'activo': true, 'orden': 1},
          ],
          'role_views': [
            {'role_code': 'admin', 'view_code': 'home', 'visible': true},
          ],
        },
      );
      await RoleViewsDataSource(_api(matrix)).getMatrix(sessionToken: 'token');
      expect(matrix.request?.path, '/api/role-views');
    },
  );

  test('401 y 403 mantienen errores de sesión y permisos', () async {
    await expectLater(
      VehiclesDataSource(
        _api(_Adapter(status: 401, body: {'error': 'invalid_session'})),
      ).getVehicles(sessionToken: 'token'),
      throwsA(
        isA<Failure>().having(
          (error) => error.type,
          'type',
          FailureType.sessionExpired,
        ),
      ),
    );
    await expectLater(
      RoleViewsDataSource(
        _api(_Adapter(status: 403, body: {'error': 'forbidden'})),
      ).getMatrix(sessionToken: 'token'),
      throwsA(
        isA<Failure>().having(
          (error) => error.type,
          'type',
          FailureType.insufficientPermissions,
        ),
      ),
    );
  });
}

ApiClient _api(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio);
}

Map<String, dynamic> _company() => {
  'id': 'company-1',
  'nombre': 'Acme',
  'activo': true,
};
Map<String, dynamic> _location() => {
  'id': 'location-1',
  'empresa_id': 'company-1',
  'nombre': 'Local',
  'latitud': -25.2,
  'longitud': -57.6,
  'radio_metros': 100,
  'activo': true,
};
Map<String, dynamic> _vehicle() => {
  'id': 'vehicle-1',
  'empresa_id': 'company-1',
  'patente': 'ABC123',
  'activo': true,
};

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, required this.body});
  final int status;
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
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
