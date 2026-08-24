class UserLocationOptionDto {
  const UserLocationOptionDto({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.isActive,
    required this.isAssigned,
    this.empresaNombre,
    this.direccion,
  });

  final String id;
  final String empresaId;
  final String nombre;
  final String? empresaNombre;
  final String? direccion;
  final bool isActive;
  final bool isAssigned;

  factory UserLocationOptionDto.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    final empresaId = _text(json['empresa_id']);
    final nombre = _text(json['nombre']);
    final activo = json['activo'];
    final assigned = json['assigned'];
    if (id == null ||
        empresaId == null ||
        nombre == null ||
        activo is! bool ||
        assigned is! bool) {
      throw const FormatException('Local inválido.');
    }
    return UserLocationOptionDto(
      id: id,
      empresaId: empresaId,
      nombre: nombre,
      empresaNombre: _optionalText(json['empresa_nombre']),
      direccion: _optionalText(json['direccion']),
      isActive: activo,
      isAssigned: assigned,
    );
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
