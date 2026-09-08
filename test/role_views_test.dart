import 'package:fleet_control/app/app_router.dart';
import 'package:fleet_control/features/authentication/data/session_storage.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/role_views/app_view_code.dart';
import 'package:fleet_control/features/role_views/data/datasources/role_views_data_source.dart';
import 'package:fleet_control/features/role_views/data/dtos/role_views_dto.dart';
import 'package:fleet_control/features/role_views/providers/current_user_views_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parsea únicamente códigos de vista soportados', () {
    final views = AppViewCode.fromValues([
      'home',
      'fleet_map',
      'vista_futura',
      12,
    ]);

    expect(views, {AppViewCode.home, AppViewCode.fleetMap});
  });

  test('canView distingue rol con y sin permiso', () {
    const allowed = CurrentUserViewsState(
      views: {AppViewCode.home, AppViewCode.vehicles},
    );
    const denied = CurrentUserViewsState(views: {AppViewCode.home});

    expect(allowed.canView(AppViewCode.vehicles), isTrue);
    expect(denied.canView(AppViewCode.vehicles), isFalse);
  });

  test('logout limpia las vistas almacenadas en memoria', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_TestSessionNotifier.new),
        sessionStorageProvider.overrideWithValue(_MemorySessionStorage()),
        roleViewsDataSourceProvider.overrideWithValue(_FakeRoleViewsGateway()),
      ],
    );
    addTearDown(container.dispose);

    container.read(currentUserViewsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(currentUserViewsProvider).canView(AppViewCode.fleetMap),
      isTrue,
    );

    container.read(sessionProvider.notifier).localSignOut();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserViewsProvider).views, isEmpty);
  });

  test('el guard resuelve la vista requerida por la ruta', () {
    expect(requiredViewForPath('/fleet-map'), AppViewCode.fleetMap);
    expect(requiredViewForPath('/vehicles/123/edit'), AppViewCode.vehicles);
    expect(
      requiredViewForPath('/settings/role-views'),
      AppViewCode.roleViewsManagement,
    );
  });
}

class _TestSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => SessionState.authenticated(
    AuthSession(
      user: const AuthenticatedUser(
        id: 'user-id',
        roleId: 'role-id',
        role: 'super_admin',
        nombre: 'Test',
        usuario: 'test',
        isActive: true,
      ),
      sessionToken: 'test-token',
      expiresAt: DateTime(2030),
    ),
  );
}

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<bool> readBiometricUnlockEnabled() async => false;

  @override
  Future<void> writeBiometricUnlockEnabled(bool enabled) async {}
}

class _FakeRoleViewsGateway implements RoleViewsGateway {
  @override
  Future<Set<AppViewCode>> getMyViews({required String sessionToken}) async => {
    AppViewCode.home,
    AppViewCode.fleetMap,
  };

  @override
  Future<RoleViewsMatrixDto> getMatrix({required String sessionToken}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateView({
    required String sessionToken,
    required String roleCode,
    required String viewCode,
    required bool visible,
  }) {
    throw UnimplementedError();
  }
}
