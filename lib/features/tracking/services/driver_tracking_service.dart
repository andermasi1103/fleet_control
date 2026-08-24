import 'package:geolocator/geolocator.dart';

enum DriverLocationAccess {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class DriverTrackingService {
  static const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20,
  );

  Future<DriverLocationAccess> requestLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return DriverLocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return DriverLocationAccess.permissionDeniedForever;
    }

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return DriverLocationAccess.permissionDenied;
    }

    return DriverLocationAccess.granted;
  }

  Future<Position> getInitialPosition() {
    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
