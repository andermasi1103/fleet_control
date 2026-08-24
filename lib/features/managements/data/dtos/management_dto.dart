class DriverDto {
  const DriverDto({
    required this.id,
    required this.name,
    required this.username,
  });
  final String id, name, username;
  factory DriverDto.fromJson(Map<String, dynamic> j) => DriverDto(
    id: j['id'] as String,
    name: j['nombre'] as String,
    username: j['usuario'] as String,
  );
}

class ManagementEventDto {
  const ManagementEventDto({required this.status, required this.createdAt});
  final String status;
  final DateTime createdAt;
  factory ManagementEventDto.fromJson(Map<String, dynamic> j) =>
      ManagementEventDto(
        status: j['estado_nuevo'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ManagementDto {
  const ManagementDto({
    required this.id,
    required this.orderId,
    required this.managementStatus,
    required this.orderStatus,
    required this.companyId,
    required this.localId,
    required this.driverUserId,
    required this.vehicleId,
    required this.createdAt,
    this.companyName,
    this.localName,
    this.driverName,
    this.driverUsername,
    this.vehiclePlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.description,
    this.destination,
    this.latitude,
    this.longitude,
    this.invoiceRequest,
    this.contactNumber,
    this.priority,
    this.notes,
    this.acceptedAt,
    this.onTheWayAt,
    this.inProgressAt,
    this.completedAt,
    this.queuePosition,
    this.events = const [],
  });
  final String id,
      orderId,
      managementStatus,
      orderStatus,
      companyId,
      localId,
      driverUserId,
      vehicleId;
  final DateTime createdAt;
  final String? companyName,
      localName,
      driverName,
      driverUsername,
      vehiclePlate,
      vehicleBrand,
      vehicleModel,
      description,
      destination,
      invoiceRequest,
      contactNumber,
      priority,
      notes;
  final double? latitude, longitude;
  final DateTime? acceptedAt, onTheWayAt, inProgressAt, completedAt;
  final int? queuePosition;
  final List<ManagementEventDto> events;
  factory ManagementDto.fromJson(Map<String, dynamic> j) {
    String req(String k) => j[k] as String;
    String? txt(String k) => j[k] as String?;
    DateTime? dt(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    double? n(String k) => (j[k] as num?)?.toDouble();
    return ManagementDto(
      id: req('id'),
      orderId: req('order_id'),
      managementStatus: req('management_status'),
      orderStatus: req('order_status'),
      companyId: req('empresa_id'),
      localId: req('local_id'),
      driverUserId: req('chofer_usuario_id'),
      vehicleId: req('vehiculo_id'),
      createdAt: DateTime.parse(req('created_at')),
      companyName: txt('empresa_nombre'),
      localName: txt('local_nombre'),
      driverName: txt('driver_name'),
      driverUsername: txt('driver_username'),
      vehiclePlate: txt('vehicle_plate'),
      vehicleBrand: txt('vehicle_brand'),
      vehicleModel: txt('vehicle_model'),
      description: txt('description'),
      destination: txt('destino'),
      latitude: n('destino_latitud'),
      longitude: n('destino_longitud'),
      invoiceRequest: txt('factura_solicitud'),
      contactNumber: txt('numero_contacto'),
      priority: txt('prioridad'),
      notes: txt('observaciones_pedido'),
      acceptedAt: dt('aceptado_at'),
      onTheWayAt: dt('en_camino_at'),
      inProgressAt: dt('en_gestion_at'),
      completedAt: dt('completado_at'),
      queuePosition: (j['queue_position'] as num?)?.toInt(),
      events: (j['events'] as List? ?? [])
          .map((x) => ManagementEventDto.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
    );
  }
}

class CreateManagementRequest {
  const CreateManagementRequest(this.orderId, this.driverId, this.vehicleId);
  final String orderId, driverId, vehicleId;
  Map<String, String> toJson() => {
    'order_id': orderId,
    'driver_user_id': driverId,
    'vehicle_id': vehicleId,
  };
}
