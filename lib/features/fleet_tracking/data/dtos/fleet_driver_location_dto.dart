class FleetDriverLocationDto {
  const FleetDriverLocationDto({
    required this.driverUserId,
    required this.driverName,
    required this.driverUsername,
    required this.connectionStatus,
    required this.operationalStatus,
    this.vehiclePlate,
    this.vehicleType,
    this.managementStatus,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  final String driverUserId;
  final String driverName;
  final String driverUsername;
  final String connectionStatus;
  final String operationalStatus;
  final String? vehiclePlate;
  final String? vehicleType;
  final String? managementStatus;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;

  bool get hasLocation => latitude != null && longitude != null;

  factory FleetDriverLocationDto.fromJson(Map<String, dynamic> json) {
    return FleetDriverLocationDto(
      driverUserId: json['driver_user_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? 'Chofer',
      driverUsername: json['driver_username']?.toString() ?? '',
      connectionStatus: json['connection_status']?.toString() ?? 'offline',
      operationalStatus: json['operational_status']?.toString() ?? 'disponible',
      vehiclePlate: _stringOrNull(json['vehicle_plate']),
      vehicleType: _stringOrNull(json['vehicle_type']),
      managementStatus: _stringOrNull(json['management_status']),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      capturedAt: _dateOrNull(json['captured_at']),
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _doubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
