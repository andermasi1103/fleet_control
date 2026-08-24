class TrackingPosition {
  const TrackingPosition({
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
}
