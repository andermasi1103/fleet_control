import '../../domain/entities/authenticated_user.dart';

class UserProfileDto {
  const UserProfileDto({
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

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      id: json['id']?.toString() ?? '',
      empresaId:
          json['empresaId']?.toString() ?? json['empresa_id']?.toString(),
      roleId: json['roleId']?.toString() ?? json['rol_id']?.toString() ?? '',
      role: json['rolCodigo']?.toString() ?? json['rol']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      usuario: json['usuario']?.toString() ?? '',
      isActive: json['activo'] != false,
    );
  }

  AuthenticatedUser toDomain() {
    return AuthenticatedUser(
      id: id,
      empresaId: empresaId,
      roleId: roleId,
      role: role,
      nombre: nombre,
      usuario: usuario,
      isActive: isActive,
    );
  }
}
