import 'package:geolocator/geolocator.dart';

enum LocationServiceError {
  disabled,
  denied,
  deniedForever,
  unavailable,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.error);

  final LocationServiceError error;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException(LocationServiceError.disabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(LocationServiceError.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(LocationServiceError.denied);
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      throw const LocationServiceException(LocationServiceError.unavailable);
    }
  }
}
