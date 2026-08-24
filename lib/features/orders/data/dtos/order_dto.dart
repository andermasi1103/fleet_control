class OrderDto {
  const OrderDto({
    required this.id,
    required this.companyId,
    required this.locationId,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.companyName,
    this.locationName,
    this.descriptionId,
    this.description,
    this.destination,
    this.latitude,
    this.longitude,
    this.invoiceRequest,
    this.contactNumber,
    this.notes,
    this.createdByName,
  });
  final String id, companyId, locationId, priority, status;
  final DateTime createdAt;
  final String? companyName,
      locationName,
      descriptionId,
      description,
      destination,
      invoiceRequest,
      contactNumber,
      notes,
      createdByName;
  final double? latitude, longitude;
  factory OrderDto.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw const FormatException();
    }

    String? text(String key) =>
        json[key] is String && (json[key] as String).trim().isNotEmpty
        ? (json[key] as String).trim()
        : null;
    double? number(String key) =>
        json[key] is num ? (json[key] as num).toDouble() : null;
    final created = DateTime.tryParse(requiredText('created_at'));
    if (created == null) throw const FormatException();
    return OrderDto(
      id: requiredText('id'),
      companyId: requiredText('empresa_id'),
      locationId: requiredText('local_id'),
      priority: requiredText('prioridad'),
      status: requiredText('estado'),
      createdAt: created,
      companyName: text('empresa_nombre'),
      locationName: text('local_nombre'),
      descriptionId: text('descripcion_tipo_id'),
      description: text('descripcion'),
      destination: text('destino'),
      latitude: number('destino_latitud'),
      longitude: number('destino_longitud'),
      invoiceRequest: text('factura_solicitud'),
      contactNumber: text('numero_contacto'),
      notes: text('observaciones'),
      createdByName: text('creado_por_nombre'),
    );
  }
}

class OrderDescriptionDto {
  const OrderDescriptionDto({
    required this.id,
    required this.companyId,
    required this.name,
    required this.isActive,
  });
  final String id, companyId, name;
  final bool isActive;
  factory OrderDescriptionDto.fromJson(Map<String, dynamic> json) =>
      OrderDescriptionDto(
        id: json['id'] as String,
        companyId: json['empresa_id'] as String,
        name: json['nombre'] as String,
        isActive: json['activo'] as bool,
      );
}

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.locationId,
    required this.descriptionId,
    required this.priority,
    this.destination,
    this.latitude,
    this.longitude,
    this.invoiceRequest,
    this.contactNumber,
    this.notes,
  });
  final String locationId, descriptionId, priority;
  final String? destination, invoiceRequest, contactNumber, notes;
  final double? latitude, longitude;
  Map<String, dynamic> toJson() => {
    'local_id': locationId,
    'descripcion_tipo_id': descriptionId,
    'prioridad': priority,
    'destino': destination,
    'destino_latitud': latitude,
    'destino_longitud': longitude,
    'factura_solicitud': invoiceRequest,
    'numero_contacto': contactNumber,
    'observaciones': notes,
  };
}
