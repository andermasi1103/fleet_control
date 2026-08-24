class UserDto {
  const UserDto({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.roleId,
    required this.isActive,
    this.companyId,
    this.companyName,
    this.role,
    this.createdAt,
  });

  final String id;
  final String usuario;
  final String nombre;
  final String roleId;
  final bool isActive;
  final String? companyId;
  final String? companyName;
  final String? role;
  final DateTime? createdAt;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    final id = _requiredText(json['id']);
    final usuario = _requiredText(json['usuario']);
    final nombre = _requiredText(json['nombre']);
    final roleId = _requiredText(json['rol_id']);
    final active = json['activo'];
    if (id == null ||
        usuario == null ||
        nombre == null ||
        roleId == null ||
        active is! bool) {
      throw const FormatException('Usuario inválido.');
    }
    return UserDto(
      id: id,
      usuario: usuario,
      nombre: nombre,
      roleId: roleId,
      isActive: active,
      companyId: _optionalText(json['empresa_id']),
      companyName: _optionalText(json['empresa_nombre']),
      role: _optionalText(json['rol']),
      createdAt: _date(json['created_at']),
    );
  }

  static String? _requiredText(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const FormatException('Fecha de usuario inválida.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw const FormatException('Fecha de usuario inválida.');
    }
    return date;
  }
}
