class AppViewDto {
  const AppViewDto({
    required this.code,
    required this.name,
    required this.isActive,
    required this.order,
    this.description,
  });

  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final int order;

  factory AppViewDto.fromJson(Map<String, dynamic> json) {
    final code = json['codigo'];
    final name = json['nombre'];
    final active = json['activo'];
    if (code is! String || code.isEmpty || name is! String || name.isEmpty ||
        active is! bool) {
      throw const FormatException('Vista inválida.');
    }
    return AppViewDto(
      code: code,
      name: name,
      description: json['descripcion'] as String?,
      isActive: active,
      order: (json['orden'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoleDto {
  const RoleDto({required this.code});

  final String code;

  factory RoleDto.fromJson(Map<String, dynamic> json) {
    final code = json['codigo'];
    if (code is! String || code.isEmpty) {
      throw const FormatException('Rol inválido.');
    }
    return RoleDto(code: code);
  }
}

class RoleViewDto {
  const RoleViewDto({
    required this.roleCode,
    required this.viewCode,
    required this.visible,
  });

  final String roleCode;
  final String viewCode;
  final bool visible;

  factory RoleViewDto.fromJson(Map<String, dynamic> json) {
    final roleCode = json['role_code'];
    final viewCode = json['view_code'];
    final visible = json['visible'];
    if (roleCode is! String || viewCode is! String || visible is! bool) {
      throw const FormatException('Configuración de vista inválida.');
    }
    return RoleViewDto(
      roleCode: roleCode,
      viewCode: viewCode,
      visible: visible,
    );
  }
}

class RoleViewsMatrixDto {
  const RoleViewsMatrixDto({
    required this.roles,
    required this.views,
    required this.assignments,
  });

  final List<RoleDto> roles;
  final List<AppViewDto> views;
  final List<RoleViewDto> assignments;
}
