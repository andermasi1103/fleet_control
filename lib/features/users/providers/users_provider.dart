import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../companies/providers/companies_provider.dart'
    show companiesDataSourceProvider;
import '../data/datasources/users_data_source.dart';
import 'users_state.dart';

final usersDataSourceProvider = Provider<UsersDataSource>((ref) {
  return UsersDataSource(ref.watch(backendApiClientProvider));
});

final usersProvider = NotifierProvider<UsersNotifier, UsersState>(
  UsersNotifier.new,
);

class UsersNotifier extends Notifier<UsersState> {
  @override
  UsersState build() => const UsersState();

  Future<void> load() async {
    final token = _sessionToken();
    if (token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final dataSource = ref.read(usersDataSourceProvider);
      final users = await dataSource.getUsers(sessionToken: token);
      final roles = await dataSource.getRoles(sessionToken: token);
      var companies = state.companies;
      try {
        companies = await ref
            .read(companiesDataSourceProvider)
            .getCompanies(sessionToken: token);
      } on Failure {
        // El listado de usuarios sigue disponible aunque el selector se cargue después.
      } catch (_) {}
      state = UsersState(
        users: users,
        companies: companies,
        roles: roles,
        searchQuery: state.searchQuery,
      );
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar los usuarios.',
      );
    }
  }

  Future<void> refresh() => load();

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<bool> createUser({
    required String nombre,
    required String usuario,
    required String password,
    required String? companyId,
    required String roleId,
  }) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await ref
          .read(usersDataSourceProvider)
          .createUser(
            sessionToken: token,
            nombre: nombre,
            usuario: usuario,
            password: password,
            companyId: companyId,
            roleId: roleId,
          );
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Usuario creado correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  Future<bool> updateUser({
    required String id,
    required String nombre,
    required String usuario,
    required String? companyId,
    required String roleId,
    required bool isActive,
  }) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final updatedUser = await ref
          .read(usersDataSourceProvider)
          .updateUser(
            sessionToken: token,
            id: id,
            nombre: nombre,
            usuario: usuario,
            companyId: companyId,
            roleId: roleId,
            isActive: isActive,
          );
      final currentUser = ref.read(sessionProvider).session?.user;
      if (currentUser?.id == updatedUser.id) {
        ref
            .read(sessionProvider.notifier)
            .updateCurrentUser(
              currentUser!.copyWith(
                empresaId: updatedUser.companyId,
                roleId: updatedUser.roleId,
                role: updatedUser.role ?? currentUser.role,
                nombre: updatedUser.nombre,
                usuario: updatedUser.usuario,
                isActive: updatedUser.isActive,
              ),
            );
      }
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Usuario actualizado correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String userId,
    required String password,
  }) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(
      isResettingPassword: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await ref
          .read(usersDataSourceProvider)
          .resetPassword(
            sessionToken: token,
            userId: userId,
            password: password,
          );
      state = state.copyWith(
        isResettingPassword: false,
        successMessage: 'Contraseña restablecida correctamente.',
      );
      return true;
    } on Failure catch (error) {
      state = state.copyWith(
        isResettingPassword: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isResettingPassword: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  bool _sessionFailure() {
    state = state.copyWith(
      errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
    );
    return false;
  }

  String? _sessionToken() {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      return null;
    }
    return session.sessionToken;
  }
}
