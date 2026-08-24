import '../../../../core/errors/failure.dart';
import '../../domain/entities/tracking_position.dart';

class TrackingPositionDto {
  const TrackingPositionDto({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.attributes,
  });

  final int id;
  final int deviceId;
  final double latitude;
  final double longitude;
  final double speed;
  final Map<String, dynamic> attributes;

  factory TrackingPositionDto.fromJson(Map<String, dynamic> json) {
    return TrackingPositionDto(
      id: _readInt(json, 'id'),
      deviceId: _readInt(json, 'deviceId'),
      latitude: _readDouble(json, 'latitude'),
      longitude: _readDouble(json, 'longitude'),
      speed: _readDouble(json, 'speed'),
      attributes: _readAttributes(json['attributes']),
    );
  }

  TrackingPosition toDomain() {
    return TrackingPosition(
      id: id,
      deviceId: deviceId,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      attributes: attributes,
    );
  }

  static int _readInt(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }

    throw Failure(
      message: 'La posición de Traccar no contiene $field válido.',
      type: FailureType.traccar,
    );
  }

  static double _readDouble(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is num) {
      return value.toDouble();
    }

    throw Failure(
      message: 'La posición de Traccar no contiene $field válido.',
      type: FailureType.traccar,
    );
  }

  static Map<String, dynamic> _readAttributes(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(value),
      );
    }

    throw const Failure(
      message: 'La posición de Traccar no contiene atributos válidos.',
      type: FailureType.traccar,
    );
  }
}
