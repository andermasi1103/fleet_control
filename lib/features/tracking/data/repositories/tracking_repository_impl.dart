import '../../domain/entities/tracking_device.dart';
import '../../domain/entities/tracking_event.dart';
import '../../domain/entities/tracking_position.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/traccar_tracking_data_source.dart';
import '../dtos/tracking_position_dto.dart';
import '../dtos/tracking_resource_dto.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._dataSource);

  final TraccarTrackingDataSource _dataSource;

  @override
  Future<List<TrackingDevice>> getDevices() async {
    final data = await _dataSource.getDevices();
    return data
        .map(TrackingResourceDto.fromJson)
        .map((dto) => TrackingDevice(dto.data))
        .toList(growable: false);
  }

  @override
  Future<List<TrackingPosition>> getPositions() async {
    final data = await _dataSource.getPositions();
    return data
        .map(TrackingPositionDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  Future<List<TrackingEvent>> getEvents() async {
    final data = await _dataSource.getEvents();
    return data
        .map(TrackingResourceDto.fromJson)
        .map((dto) => TrackingEvent(dto.data))
        .toList(growable: false);
  }
}
