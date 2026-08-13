import '../../../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String nombre;
  final String usuario;
  final String rol;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      usuario: json['usuario']?.toString() ?? '',
      rol: json['rol']?.toString() ?? AppConstants.userRole,
      isActive: json['activo'] == true,
    );
  }

  bool get isAdmin => rol == AppConstants.adminRole;

  bool get isSupervisor =>
      rol == AppConstants.supervisorRole;

  bool get isChofer =>
      rol == AppConstants.choferRole;

  bool get isUser =>
      rol == AppConstants.userRole;

  String get displayName {
    if (nombre.trim().isNotEmpty) {
      return nombre;
    }

    return usuario;
  }
}