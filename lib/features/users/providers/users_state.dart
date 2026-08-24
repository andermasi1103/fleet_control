import '../../companies/data/dtos/company_dto.dart';
import '../data/dtos/role_option_dto.dart';
import '../data/dtos/user_dto.dart';

class UsersState {
  const UsersState({
    this.isLoading = false,
    this.isSaving = false,
    this.isResettingPassword = false,
    this.users = const [],
    this.companies = const [],
    this.roles = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final bool isResettingPassword;
  final List<UserDto> users;
  final List<CompanyDto> companies;
  final List<RoleOptionDto> roles;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  List<UserDto> get filteredUsers {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users
        .where((user) {
          return user.nombre.toLowerCase().contains(query) ||
              user.usuario.toLowerCase().contains(query) ||
              (user.role?.toLowerCase().contains(query) ?? false) ||
              (user.companyName?.toLowerCase().contains(query) ?? false) ||
              (user.isActive ? 'activo' : 'inactivo').contains(query);
        })
        .toList(growable: false);
  }

  UsersState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isResettingPassword,
    List<UserDto>? users,
    List<CompanyDto>? companies,
    List<RoleOptionDto>? roles,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return UsersState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isResettingPassword: isResettingPassword ?? this.isResettingPassword,
      users: users ?? this.users,
      companies: companies ?? this.companies,
      roles: roles ?? this.roles,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
