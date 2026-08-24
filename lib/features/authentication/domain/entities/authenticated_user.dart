class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.roleId,
    required this.role,
    required this.nombre,
    required this.usuario,
    required this.isActive,
    this.empresaId,
  });

  final String id;
  final String? empresaId;
  final String roleId;
  final String role;
  final String nombre;
  final String usuario;
  final bool isActive;

  String get displayName =>
      nombre.trim().isEmpty ? usuario : nombre;

  AuthenticatedUser copyWith({
    String? id,
    String? empresaId,
    String? roleId,
    String? role,
    String? nombre,
    String? usuario,
    bool? isActive,
  }) {
    return AuthenticatedUser(
      id: id ?? this.id,
      empresaId: empresaId ?? this.empresaId,
      roleId: roleId ?? this.roleId,
      role: role ?? this.role,
      nombre: nombre ?? this.nombre,
      usuario: usuario ?? this.usuario,
      isActive: isActive ?? this.isActive,
    );
  }
}