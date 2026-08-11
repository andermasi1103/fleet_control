import '../../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String nombre;   // coincide con JSON
  final String usuario;  // coincide con JSON
  final String rol;
  final bool isActive;   // boolean real

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
      // 🔹 Supabase devuelve bool directamente
      isActive: json['activo'] == true,
    );
  }

  bool get isAdmin => rol == AppConstants.adminRole;
  bool get isUser => rol == AppConstants.userRole;

  String get displayName => nombre.isEmpty ? usuario : nombre;
}
