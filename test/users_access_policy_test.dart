import 'package:dio/dio.dart';
import 'package:fleet_control/core/network/api_client.dart';
import 'package:fleet_control/features/authentication/domain/entities/auth_session.dart';
import 'package:fleet_control/features/authentication/domain/entities/authenticated_user.dart';
import 'package:fleet_control/features/authentication/providers/session_provider.dart';
import 'package:fleet_control/features/authentication/providers/session_state.dart';
import 'package:fleet_control/features/companies/data/datasources/companies_data_source.dart';
import 'package:fleet_control/features/companies/data/dtos/company_dto.dart';
import 'package:fleet_control/features/companies/providers/companies_provider.dart';
import 'package:fleet_control/features/users/data/datasources/users_data_source.dart';
import 'package:fleet_control/features/users/data/dtos/role_option_dto.dart';
import 'package:fleet_control/features/users/data/dtos/user_dto.dart';
import 'package:fleet_control/features/users/presentation/widgets/user_card.dart';
import 'package:fleet_control/features/users/providers/users_provider.dart';
import 'package:fleet_control/features/users/user_access_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supervisor carga usuarios sin solicitar roles asignables', () async {
    final source = _RecordingUsersDataSource();
    final container = _container(source, role: 'supervisor');
    addTearDown(container.dispose);

    await container.read(usersProvider.notifier).load();

    expect(source.userCalls, 1);
    expect(source.roleCalls, 0);
    expect(container.read(usersProvider).errorMessage, isNull);
  });

  test('admin solicita los roles asignables', () async {
    final source = _RecordingUsersDataSource();
    final container = _container(source, role: 'admin');
    addTearDown(container.dispose);

    await container.read(usersProvider.notifier).load();

    expect(source.roleCalls, 1);
    expect(
      container.read(usersProvider).roles.map((role) => role.code),
      ['user', 'admin'],
    );
  });

  test('la política de cliente no expone acciones administrativas al supervisor', () {
    expect(canManageUsers('super_admin'), isTrue);
    expect(canManageUsers('admin'), isTrue);
    expect(canManageUsers('supervisor'), isFalse);
    expect(canManageUserLocations('supervisor'), isTrue);
    expect(canManageUsers('chofer'), isFalse);
    expect(canManageUserLocations('local'), isFalse);
  });

  testWidgets('la tarjeta de supervisor conserva solo la asignación de locales', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserCard(
            user: const UserDto(
              id: 'user-1',
              usuario: 'operador',
              nombre: 'Operador',
              roleId: 'role-1',
              isActive: true,
              role: 'chofer',
            ),
            onEdit: null,
            onResetPassword: null,
            onAssignLocations: () {},
          ),
        ),
      ),
    );

    expect(find.text('ASIGNAR LOCALES'), findsOneWidget);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('RESTABLECER CONTRASEÑA'), findsNothing);
  });
}

ProviderContainer _container(_RecordingUsersDataSource source, {required String role}) =>
    ProviderContainer(
      overrides: [
        usersDataSourceProvider.overrideWithValue(source),
        companiesDataSourceProvider.overrideWithValue(_CompaniesDataSource()),
        sessionProvider.overrideWith(() => _SessionNotifier(role)),
      ],
    );

class _RecordingUsersDataSource extends UsersDataSource {
  _RecordingUsersDataSource() : super(ApiClient(Dio()));

  int userCalls = 0;
  int roleCalls = 0;

  @override
  Future<List<UserDto>> getUsers({required String sessionToken}) async {
    userCalls++;
    return const [
      UserDto(
        id: 'user-1',
        usuario: 'operador',
        nombre: 'Operador',
        roleId: 'role-1',
        isActive: true,
        role: 'chofer',
      ),
    ];
  }

  @override
  Future<List<RoleOptionDto>> getRoles({required String sessionToken}) async {
    roleCalls++;
    return const [
      RoleOptionDto(id: 'role-1', code: 'user'),
      RoleOptionDto(id: 'role-2', code: 'admin'),
    ];
  }
}

class _CompaniesDataSource extends CompaniesDataSource {
  _CompaniesDataSource() : super(ApiClient(Dio()));

  @override
  Future<List<CompanyDto>> getCompanies({required String sessionToken}) async =>
      [];
}

class _SessionNotifier extends SessionNotifier {
  _SessionNotifier(this.role);

  final String role;

  @override
  SessionState build() => SessionState.authenticated(
    AuthSession(
      user: AuthenticatedUser(
        id: 'user-1',
        roleId: 'role-1',
        role: role,
        nombre: 'Usuario de prueba',
        usuario: 'prueba',
        isActive: true,
      ),
      sessionToken: 'session-token',
      expiresAt: DateTime(2030),
    ),
  );
}
