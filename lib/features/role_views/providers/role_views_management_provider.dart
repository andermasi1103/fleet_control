import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/dtos/role_views_dto.dart';
import 'current_user_views_provider.dart';

class RoleViewsManagementState {
  const RoleViewsManagementState({
    this.isLoading = false,
    this.roles = const [],
    this.views = const [],
    this.visibility = const {},
    this.savingKeys = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final List<RoleDto> roles;
  final List<AppViewDto> views;
  final Map<String, bool> visibility;
  final Set<String> savingKeys;
  final String? errorMessage;

  bool isVisible(String roleCode, String viewCode) =>
      visibility[_key(roleCode, viewCode)] ?? false;

  bool isSaving(String roleCode, String viewCode) =>
      savingKeys.contains(_key(roleCode, viewCode));

  RoleViewsManagementState copyWith({
    bool? isLoading,
    List<RoleDto>? roles,
    List<AppViewDto>? views,
    Map<String, bool>? visibility,
    Set<String>? savingKeys,
    String? errorMessage,
    bool clearError = false,
  }) => RoleViewsManagementState(
    isLoading: isLoading ?? this.isLoading,
    roles: roles ?? this.roles,
    views: views ?? this.views,
    visibility: visibility ?? this.visibility,
    savingKeys: savingKeys ?? this.savingKeys,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

String _key(String roleCode, String viewCode) => '$roleCode::$viewCode';

final roleViewsManagementProvider =
    NotifierProvider<RoleViewsManagementNotifier, RoleViewsManagementState>(
      RoleViewsManagementNotifier.new,
    );

class RoleViewsManagementNotifier extends Notifier<RoleViewsManagementState> {
  @override
  RoleViewsManagementState build() => const RoleViewsManagementState();

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = const RoleViewsManagementState(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final matrix = await ref
          .read(roleViewsDataSourceProvider)
          .getMatrix(sessionToken: token);
      state = RoleViewsManagementState(
        roles: matrix.roles,
        views: matrix.views,
        visibility: {
          for (final item in matrix.assignments)
            _key(item.roleCode, item.viewCode): item.visible,
        },
      );
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar los roles y vistas.',
      );
    }
  }

  Future<String?> update({
    required String roleCode,
    required String viewCode,
    required bool visible,
  }) async {
    final token = _token;
    if (token == null) return 'Tu sesión ha vencido. Inicia sesión nuevamente.';
    final key = _key(roleCode, viewCode);
    if (state.savingKeys.contains(key)) return null;
    final previous = state.visibility[key] ?? false;
    state = state.copyWith(
      visibility: {...state.visibility, key: visible},
      savingKeys: {...state.savingKeys, key},
      clearError: true,
    );
    try {
      await ref.read(roleViewsDataSourceProvider).updateView(
            sessionToken: token,
            roleCode: roleCode,
            viewCode: viewCode,
            visible: visible,
          );
      state = state.copyWith(
        savingKeys: {...state.savingKeys}..remove(key),
      );
      return null;
    } on Failure catch (error) {
      state = state.copyWith(
        visibility: {...state.visibility, key: previous},
        savingKeys: {...state.savingKeys}..remove(key),
        errorMessage: error.message,
      );
      return error.message;
    } catch (_) {
      const message = 'No fue posible guardar la configuración de vistas.';
      state = state.copyWith(
        visibility: {...state.visibility, key: previous},
        savingKeys: {...state.savingKeys}..remove(key),
        errorMessage: message,
      );
      return message;
    }
  }

  String? get _token {
    final session = ref.read(sessionProvider).session;
    return session == null || session.isExpired || session.sessionToken.isEmpty
        ? null
        : session.sessionToken;
  }
}
