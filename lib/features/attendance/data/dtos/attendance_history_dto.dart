class AttendanceHistoryDto {
  const AttendanceHistoryDto({
    required this.id,
    required this.userId,
    required this.tipo,
    required this.fechaHora,
    this.empresaId,
    this.localId,
    this.usuarioNombre,
    this.empresaNombre,
    this.localNombre,
    this.latitud,
    this.longitud,
    this.dentroGeocerca,
  });

  final String id;
  final String userId;
  final String tipo;
  final DateTime fechaHora;
  final String? empresaId;
  final String? localId;
  final String? usuarioNombre;
  final String? empresaNombre;
  final String? localNombre;
  final double? latitud;
  final double? longitud;
  final bool? dentroGeocerca;

  factory AttendanceHistoryDto.fromJson(Map<String, dynamic> json) {
    final id = _requiredText(json['id']);
    final userId = _requiredText(json['usuario_id']);
    final tipo = json['tipo'];
    final fechaHora = _date(json['fecha_hora']);
    if (id == null) {
      throw const FormatException('attendance-history invalid id');
    }
    if (userId == null) {
      throw const FormatException('attendance-history invalid usuario_id');
    }
    if (tipo != 'entrada' && tipo != 'salida') {
      throw const FormatException('attendance-history invalid tipo');
    }
    if (fechaHora == null) {
      throw const FormatException('attendance-history invalid fecha_hora');
    }
    return AttendanceHistoryDto(
      id: id,
      userId: userId,
      tipo: tipo,
      fechaHora: fechaHora,
      empresaId: _optionalText(json['empresa_id']),
      localId: _optionalText(json['local_id']),
      usuarioNombre: _optionalText(json['usuario_nombre']),
      empresaNombre: _optionalText(json['empresa_nombre']),
      localNombre: _optionalText(json['local_nombre']),
      latitud: _number(json['latitud']),
      longitud: _number(json['longitud']),
      dentroGeocerca: _boolean(json['dentro_geocerca']),
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
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static double? _number(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw const FormatException('Coordenadas de asistencia inválidas.');
  }

  static bool? _boolean(Object? value) {
    if (value == null || value is bool) return value as bool?;
    throw const FormatException('Geocerca de asistencia inválida.');
  }
}

class AttendanceHistoryPage {
  const AttendanceHistoryPage({
    required this.records,
    required this.limit,
    required this.offset,
    required this.total,
  });

  final List<AttendanceHistoryDto> records;
  final int limit;
  final int offset;
  final int total;
}
