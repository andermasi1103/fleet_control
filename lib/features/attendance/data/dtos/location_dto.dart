class LocationDto {
  const LocationDto({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.radioMetros,
    required this.isActive,
    this.empresaNombre,
    this.direccion,
  });

  final String id;
  final String empresaId;
  final String? empresaNombre;
  final String nombre;
  final String? direccion;
  final double latitud;
  final double longitud;
  final double radioMetros;
  final bool isActive;

  factory LocationDto.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final empresaId = json['empresa_id']?.toString() ?? '';
    final nombre = json['nombre']?.toString().trim() ?? '';
    final latitud = _number(json['latitud']);
    final longitud = _number(json['longitud']);
    final radioMetros = _number(json['radio_metros']);
    final activo = json['activo'];

    if (id.isEmpty ||
        empresaId.isEmpty ||
        nombre.isEmpty ||
        latitud == null ||
        longitud == null ||
        radioMetros == null ||
        latitud < -90 ||
        latitud > 90 ||
        longitud < -180 ||
        longitud > 180 ||
        radioMetros <= 0 ||
        activo is! bool) {
      throw const FormatException('Local inválido.');
    }

    return LocationDto(
      id: id,
      empresaId: empresaId,
      empresaNombre: _nullableText(json['empresa_nombre']),
      nombre: nombre,
      direccion: _nullableText(json['direccion']),
      latitud: latitud,
      longitud: longitud,
      radioMetros: radioMetros,
      isActive: activo,
    );
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : null;

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
