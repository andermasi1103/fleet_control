import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fleet_control/core/network/api_client.dart';
import 'package:fleet_control/features/authentication/data/datasources/fastify_auth_data_source.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/notifications/data/datasources/notifications_data_source.dart';
import 'package:fleet_control/features/profile/data/datasources/profile_data_source.dart';
import 'package:fleet_control/features/role_views/app_view_code.dart';
import 'package:fleet_control/features/role_views/data/datasources/role_views_data_source.dart';
import 'package:fleet_control/features/tracking/data/datasources/driver_location_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('login Fastify se adapta a AuthSession', () async {
    final adapter = _RecordingAdapter(body: _loginResponse());
    final source = FastifyAuthDataSource(_api(adapter));

    final response = await source.signInWithUsuarioAndPassword(
      usuario: ' operador ',
      password: 'clave-segura',
    );

    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/api/auth/login');
    expect(adapter.request?.data, {
      'usuario': 'operador',
      'password': 'clave-segura',
    });
    expect(response.user.toDomain().roleId, 'role-1');
    expect(response.user.toDomain().role, 'chofer');
    expect(response.sessionToken, 'session-token');
  });

  test('login Fastify 401 devuelve un error amigable', () async {
    final source = FastifyAuthDataSource(
      _api(
        _RecordingAdapter(
          statusCode: 401,
          body: {'error': 'invalid_credentials'},
        ),
      ),
    );

    await expectLater(
      source.signInWithUsuarioAndPassword(
        usuario: 'operador',
        password: 'incorrecta',
      ),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('Usuario o contraseña inválidos.'),
        ),
      ),
    );
  });

  test('my-views usa Fastify y Bearer', () async {
    final adapter = _RecordingAdapter(
      body: {
        'views': ['home', 'fleet_map'],
      },
    );
    final source = RoleViewsDataSource(_api(adapter));

    final views = await source.getMyViews(sessionToken: 'session-token');

    expect(adapter.request?.path, '/api/me/views');
    expect(adapter.request?.headers['Authorization'], 'Bearer session-token');
    expect(views, {AppViewCode.home, AppViewCode.fleetMap});
  });

  test(
    'notifications, mark read y dispositivos usan Fastify con Bearer',
    () async {
      final listAdapter = _RecordingAdapter(
        body: {
          'notifications': [
            {
              'id': 'notification-1',
              'tipo': 'new_order',
              'titulo': 'Nuevo pedido',
              'mensaje': 'Disponible',
              'leida': false,
              'created_at': '2030-01-01T00:00:00.000Z',
            },
          ],
        },
      );
      final listSource = NotificationsDataSource(_api(listAdapter));
      final notifications = await listSource.list('session-token');
      expect(notifications, hasLength(1));
      expect(listAdapter.request?.path, '/api/notifications');
      expect(
        listAdapter.request?.headers['Authorization'],
        'Bearer session-token',
      );

      final markAdapter = _RecordingAdapter(body: {'success': true});
      await NotificationsDataSource(
        _api(markAdapter),
      ).markRead('session-token', 'notification-1');
      expect(
        markAdapter.request?.path,
        '/api/notifications/notification-1/read',
      );
      expect(markAdapter.request?.data, isNull);

      final registerAdapter = _RecordingAdapter(body: {'success': true});
      await NotificationsDataSource(
        _api(registerAdapter),
      ).registerDevice('session-token', token: 'device-token', platform: 'web');
      expect(registerAdapter.request?.path, '/api/notification-devices');
      expect(registerAdapter.request?.data, {
        'token': 'device-token',
        'platform': 'web',
      });
      expect(registerAdapter.request?.data, isNot(contains('usuario_id')));

      final unregisterAdapter = _RecordingAdapter(body: {'success': true});
      await NotificationsDataSource(
        _api(unregisterAdapter),
      ).unregisterDevice('session-token', 'device-token');
      expect(
        unregisterAdapter.request?.path,
        '/api/notification-devices/unregister',
      );
      expect(unregisterAdapter.request?.data, {'token': 'device-token'});
    },
  );

  test(
    'driver location usa Fastify, Bearer y sólo el contrato permitido',
    () async {
      final adapter = _RecordingAdapter(body: {'location': {}});
      final source = DriverLocationDataSource(_api(adapter));

      await source.updateLocation(
        sessionToken: 'session-token',
        position: Position(
          latitude: -25.2867,
          longitude: -57.647,
          timestamp: DateTime.utc(2030),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 90,
          headingAccuracy: 0,
          speed: 2,
          speedAccuracy: 0,
        ),
      );

      expect(adapter.request?.path, '/api/driver/location');
      expect(adapter.request?.headers['Authorization'], 'Bearer session-token');
      expect(adapter.request?.data.keys, {
        'latitude',
        'longitude',
        'accuracy',
        'speed',
        'heading',
        'captured_at',
      });
    },
  );

  test('password Fastify envía el cuerpo requerido', () async {
    final adapter = _RecordingAdapter(body: {'success': true});

    await ProfileDataSource(_api(adapter)).changePassword(
      sessionToken: 'session-token',
      currentPassword: 'actual-segura',
      newPassword: 'nueva-segura',
    );

    expect(adapter.request?.path, '/api/profile/password');
    expect(adapter.request?.headers['Authorization'], 'Bearer session-token');
    expect(adapter.request?.data, {
      'currentPassword': 'actual-segura',
      'newPassword': 'nueva-segura',
    });
  });

  test(
    'logout remoto Fastify y fallo remoto siempre limpian la sesión local',
    () async {
      for (final statusCode in [200, 500]) {
        final adapter = _RecordingAdapter(
          statusCode: statusCode,
          body: statusCode == 200
              ? {'success': true}
              : {'error': 'internal_error'},
        );
        final container = ProviderContainer(
          overrides: [
            fastifyAuthDataSourceProvider.overrideWithValue(
              FastifyAuthDataSource(_api(adapter)),
            ),
            sessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await container.read(sessionProvider.notifier).signOut();

        expect(container.read(sessionProvider).isUnauthenticated, isTrue);
        expect(adapter.request?.path, '/api/auth/logout');
        expect(
          adapter.request?.headers['Authorization'],
          'Bearer session-token',
        );
      }
    },
  );

  test('cambio de contraseña exitoso limpia la sesión local', () {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(sessionProvider.notifier).endSessionAfterPasswordChange();

    expect(container.read(sessionProvider).isUnauthenticated, isTrue);
  });
}

ApiClient _api(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio);
}

Map<String, dynamic> _loginResponse() => {
  'user': {
    'id': 'user-1',
    'usuario': 'operador',
    'nombre': 'Operador',
    'empresaId': 'company-1',
    'roleId': 'role-1',
    'rolCodigo': 'chofer',
  },
  'sessionToken': 'session-token',
  'expiresAt': '2030-01-01T00:00:00.000Z',
};

class _AuthenticatedSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => SessionState.authenticated(
    AuthSession(
      user: const AuthenticatedUser(
        id: 'user-1',
        roleId: 'role-1',
        role: 'chofer',
        nombre: 'Chofer',
        usuario: 'chofer',
        isActive: true,
      ),
      sessionToken: 'session-token',
      expiresAt: DateTime(2030),
    ),
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, required this.body});

  final int statusCode;
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
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
