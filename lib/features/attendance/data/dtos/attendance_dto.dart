class AttendanceDto {
  const AttendanceDto({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.fechaHora,
    this.empresaId,
    this.latitud,
    this.longitud,
    this.dentroGeocerca,
  });

  final String id;
  final String usuarioId;
  final String? empresaId;
  final String tipo;
  final DateTime fechaHora;
  final double? latitud;
  final double? longitud;
  final bool? dentroGeocerca;

  factory AttendanceDto.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final usuarioId = json['usuario_id']?.toString() ?? '';
    final tipo = json['tipo']?.toString() ?? '';
    final fechaHoraValue = json['fecha_hora']?.toString();
    final fechaHora = fechaHoraValue == null
        ? null
        : DateTime.tryParse(fechaHoraValue);

    if (id.isEmpty || usuarioId.isEmpty || tipo.isEmpty || fechaHora == null) {
      throw const FormatException('Asistencia inválida.');
    }

    return AttendanceDto(
      id: id,
      usuarioId: usuarioId,
      empresaId: json['empresa_id']?.toString(),
      tipo: tipo,
      fechaHora: fechaHora,
      latitud: _nullableDouble(json['latitud']),
      longitud: _nullableDouble(json['longitud']),
      dentroGeocerca: _nullableBool(json['dentro_geocerca']),
    );
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw const FormatException('Coordenadas de asistencia inválidas.');
  }

  static bool? _nullableBool(dynamic value) {
    if (value == null || value is bool) {
      return value;
    }
    throw const FormatException('Geocerca de asistencia inválida.');
  }
}
