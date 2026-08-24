import '../entities/tracking_device.dart';
import '../entities/tracking_event.dart';
import '../entities/tracking_position.dart';

abstract class TrackingRepository {
  Future<List<TrackingDevice>> getDevices();

  Future<List<TrackingPosition>> getPositions();

  Future<List<TrackingEvent>> getEvents();
}
