class CompanyDto {
  const CompanyDto({
    required this.id,
    required this.nombre,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombre;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CompanyDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final activo = json['activo'];
    if (id is! String || id.isEmpty || nombre is! String || nombre.isEmpty) {
      throw const FormatException('Empresa inválida.');
    }
    if (activo is! bool) {
      throw const FormatException('Estado de empresa inválido.');
    }
    return CompanyDto(
      id: id,
      nombre: nombre,
      isActive: activo,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Fecha inválida.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Fecha inválida.');
    return parsed;
  }
}
