class RoleOptionDto {
  const RoleOptionDto({required this.id, required this.code, this.name});

  final String id;
  final String code;
  final String? name;

  factory RoleOptionDto.fromJson(Map<String, dynamic> json) {
    final id = _requiredText(json['id']);
    final code = _requiredText(json['codigo']);
    if (id == null || code == null) {
      throw const FormatException('Rol inválido.');
    }
    return RoleOptionDto(
      id: id,
      code: code,
      name: _optionalText(json['nombre']),
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
}
