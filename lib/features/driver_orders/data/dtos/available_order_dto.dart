class AvailableOrderDto {
  const AvailableOrderDto({
    required this.id,
    required this.priority,
    required this.createdAt,
    this.locationName,
    this.description,
    this.destination,
    this.latitude,
    this.longitude,
    this.invoiceRequest,
    this.contactNumber,
    this.notes,
  });

  final String id;
  final String priority;
  final DateTime createdAt;
  final String? locationName;
  final String? description;
  final String? destination;
  final double? latitude;
  final double? longitude;
  final String? invoiceRequest;
  final String? contactNumber;
  final String? notes;

  factory AvailableOrderDto.fromJson(Map<String, dynamic> json) {
    final id = json['order_id'];
    final priority = json['prioridad'];
    final createdAt = json['created_at'];
    if (id is! String || priority is! String || createdAt is! String) {
      throw const FormatException('Pedido disponible inválido.');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const FormatException('Fecha de pedido inválida.');
    }
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    double? number(String key) => (json[key] as num?)?.toDouble();

    return AvailableOrderDto(
      id: id,
      priority: priority,
      createdAt: parsedCreatedAt,
      locationName: text('local'),
      description: text('descripcion'),
      destination: text('destino'),
      latitude: number('destino_latitud'),
      longitude: number('destino_longitud'),
      invoiceRequest: text('factura_solicitud'),
      contactNumber: text('numero_contacto'),
      notes: text('observaciones'),
    );
  }
}
