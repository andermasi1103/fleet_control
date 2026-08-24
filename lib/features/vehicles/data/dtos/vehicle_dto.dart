class VehicleDto {
  const VehicleDto({
    required this.id,
    required this.companyId,
    required this.plate,
    required this.isActive,
    this.companyName,
    this.brand,
    this.model,
    this.vehicleType,
    this.year,
    this.description,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final String companyId;
  final String plate;
  final bool isActive;
  final String? companyName;
  final String? brand;
  final String? model;
  final String? vehicleType;
  final int? year;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  factory VehicleDto.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final result = value is String ? value.trim() : '';
      return result.isEmpty ? null : result;
    }

    DateTime? date(Object? value) {
      if (value == null) return null;
      if (value is! String) throw const FormatException();
      return DateTime.tryParse(value) ?? (throw const FormatException());
    }

    final id = text(json['id']);
    final companyId = text(json['empresa_id']);
    final plate = text(json['patente']);
    if (id == null ||
        companyId == null ||
        plate == null ||
        json['activo'] is! bool ||
        (json['anio'] != null && json['anio'] is! int)) {
      throw const FormatException();
    }
    return VehicleDto(
      id: id,
      companyId: companyId,
      plate: plate,
      isActive: json['activo'] as bool,
      companyName: text(json['empresa_nombre']),
      brand: text(json['marca']),
      model: text(json['modelo']),
      vehicleType: text(json['tipo_vehiculo']),
      year: json['anio'] as int?,
      description: text(json['descripcion']),
      createdAt: date(json['created_at']),
      updatedAt: date(json['updated_at']),
    );
  }
}
