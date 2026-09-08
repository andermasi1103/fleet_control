import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_control/core/network/api_client.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/orders/data/datasources/orders_data_source.dart';
import 'package:fleet_control/features/orders/presentation/order_form_screen.dart';
import 'package:fleet_control/features/orders/providers/orders_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _locationId = 'c7022215-0430-4324-ad95-ea485c7b03c3';
const _companyId = 'b926ee8a-7daa-4a18-9126-6c515a9f9761';

void main() {
  test(
    'el contrato real de /api/me/locations conserva el local activo',
    () async {
      final adapter = _OrdersAdapter();
      final source = OrdersDataSource(_api(adapter));

      final locations = await source.locations('token', administrative: false);

      expect(adapter.paths, ['/api/me/locations']);
      expect(locations, hasLength(1));
      expect(locations.single.id, _locationId);
      expect(locations.single.nombre, '003 | Palma');
      expect(locations.single.isActive, isTrue);
    },
  );

  test('un local carga pedidos vacíos y su local asignado', () async {
    final adapter = _OrdersAdapter();
    final container = _container(adapter, role: 'local');
    addTearDown(container.dispose);

    await container.read(ordersProvider.notifier).load();

    final state = container.read(ordersProvider);
    expect(
      adapter.paths,
      containsAllInOrder(['/api/orders', '/api/me/locations']),
    );
    expect(state.orders, isEmpty);
    expect(state.locations, hasLength(1));
    expect(state.locations.single.id, _locationId);
    expect(state.locations.single.nombre, '003 | Palma');
  });

  for (final role in ['admin', 'super_admin', 'supervisor']) {
    test('$role conserva /api/locations', () async {
      final adapter = _OrdersAdapter();
      final container = _container(adapter, role: role);
      addTearDown(container.dispose);

      await container.read(ordersProvider.notifier).load();

      expect(adapter.paths, contains('/api/locations'));
      expect(adapter.paths, isNot(contains('/api/me/locations')));
      expect(container.read(ordersProvider).locations, hasLength(1));
    });
  }

  testWidgets(
    'abrir directamente el formulario carga el local asignado en vez de mostrar ausencia',
    (tester) async {
      final adapter = _OrdersAdapter();
      await tester.pumpWidget(_formApp(adapter));

      expect(
        find.text('No tienes locales asignados para crear pedidos.'),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(find.text('003 | Palma'), findsOneWidget);
      expect(
        find.text('No tienes locales asignados para crear pedidos.'),
        findsNothing,
      );
    },
  );

  testWidgets('locations vacío confirmado muestra el estado sin locales', (
    tester,
  ) async {
    await tester.pumpWidget(_formApp(_OrdersAdapter(locations: const [])));
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes locales asignados para crear pedidos.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'error de /api/me/locations no se presenta como falta de locales',
    (tester) async {
      await tester.pumpWidget(_formApp(_OrdersAdapter(invalidLocation: true)));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes locales asignados para crear pedidos.'),
        findsNothing,
      );
      expect(find.text('La respuesta de locales es inválida.'), findsOneWidget);
    },
  );

  testWidgets(
    'fallo HTTP de /api/me/locations no se presenta como falta de locales',
    (tester) async {
      await tester.pumpWidget(_formApp(_OrdersAdapter(locationsStatus: 500)));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes locales asignados para crear pedidos.'),
        findsNothing,
      );
      expect(
        find.text('No fue posible completar la operación.'),
        findsOneWidget,
      );
    },
  );
}

Widget _formApp(_OrdersAdapter adapter) => ProviderScope(
  overrides: [
    ordersDataSourceProvider.overrideWithValue(OrdersDataSource(_api(adapter))),
    sessionProvider.overrideWith(() => _TestSessionNotifier('local')),
  ],
  child: const MaterialApp(home: OrderFormScreen()),
);

ProviderContainer _container(_OrdersAdapter adapter, {required String role}) =>
    ProviderContainer(
      overrides: [
        ordersDataSourceProvider.overrideWithValue(
          OrdersDataSource(_api(adapter)),
        ),
        sessionProvider.overrideWith(() => _TestSessionNotifier(role)),
      ],
    );

ApiClient _api(_OrdersAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio);
}

class _TestSessionNotifier extends SessionNotifier {
  _TestSessionNotifier(this.role);

  final String role;

  @override
  SessionState build() => SessionState.authenticated(
    AuthSession(
      user: AuthenticatedUser(
        id: 'local-user',
        roleId: 'local-role',
        role: role,
        nombre: 'Local 1',
        usuario: 'local1',
        isActive: true,
        empresaId: _companyId,
      ),
      sessionToken: 'token',
      expiresAt: DateTime(2030),
    ),
  );
}

class _OrdersAdapter implements HttpClientAdapter {
  _OrdersAdapter({
    this.locations = const [_realLocation],
    this.invalidLocation = false,
    this.locationsStatus,
  });

  final List<Map<String, dynamic>> locations;
  final bool invalidLocation;
  final int? locationsStatus;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final isLocationsPath =
        options.path == '/api/me/locations' || options.path == '/api/locations';
    final body = switch (options.path) {
      '/api/orders' => {'orders': [], 'limit': 20, 'offset': 0, 'total': 0},
      '/api/me/locations' || '/api/locations' => {
        'locations': invalidLocation
            ? [
                {'id': _locationId, 'activo': true},
              ]
            : locations,
      },
      '/api/order-descriptions' => {'descriptions': []},
      _ => {'error': 'unexpected_path'},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      isLocationsPath ? locationsStatus ?? 200 : 200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _realLocation = {
  'id': _locationId,
  'empresa_id': _companyId,
  'codigo': 'LOC-003',
  'nombre': '003 | Palma',
  'direccion': 'Palma esq. 15 de agosto',
  'descripcion': null,
  'latitud': -25.280643219321934,
  'longitud': -57.63756206790376,
  'radio_metros': 100,
  'activo': true,
};
