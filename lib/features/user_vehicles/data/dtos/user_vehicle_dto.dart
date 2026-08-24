class UserVehicleOptionDto {
  const UserVehicleOptionDto({
    required this.id,
    required this.plate,
    this.brand,
    this.model,
    this.vehicleType,
  });

  final String id;
  final String plate;
  final String? brand;
  final String? model;
  final String? vehicleType;

  String get label {
    final details = [brand, model].whereType<String>().join(' ');
    return details.isEmpty ? plate : '$plate · $details';
  }

  factory UserVehicleOptionDto.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final result = value is String ? value.trim() : '';
      return result.isEmpty ? null : result;
    }

    final id = text(json['id']);
    final plate = text(json['patente']);
    if (id == null || plate == null) throw const FormatException();
    return UserVehicleOptionDto(
      id: id,
      plate: plate,
      brand: text(json['marca']),
      model: text(json['modelo']),
      vehicleType: text(json['tipo_vehiculo']),
    );
  }
}

class UserVehicleDto {
  const UserVehicleDto({
    required this.userId,
    required this.vehicleId,
    this.vehicle,
  });

  final String userId;
  final String vehicleId;
  final UserVehicleOptionDto? vehicle;

  factory UserVehicleDto.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final vehicleId = json['vehicle_id'];
    if (userId is! String ||
        userId.isEmpty ||
        vehicleId is! String ||
        vehicleId.isEmpty) {
      throw const FormatException();
    }
    final vehicle = json['vehicle'];
    return UserVehicleDto(
      userId: userId,
      vehicleId: vehicleId,
      vehicle: vehicle is Map
          ? UserVehicleOptionDto.fromJson(Map<String, dynamic>.from(vehicle))
          : null,
    );
  }
}

class UserVehicleLookupDto {
  const UserVehicleLookupDto({
    required this.assignment,
    required this.vehicles,
  });

  final UserVehicleDto? assignment;
  final List<UserVehicleOptionDto> vehicles;
}
