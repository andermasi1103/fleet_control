class CompanyOptionDto {
  const CompanyOptionDto({
    required this.id,
    required this.nombre,
    required this.isActive,
  });

  final String id;
  final String nombre;
  final bool isActive;

  factory CompanyOptionDto.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final nombre = json['nombre']?.toString().trim() ?? '';
    final activo = json['activo'];
    if (id.isEmpty || nombre.isEmpty || activo is! bool) {
      throw const FormatException('Empresa inválida.');
    }
    return CompanyOptionDto(id: id, nombre: nombre, isActive: activo);
  }
}
