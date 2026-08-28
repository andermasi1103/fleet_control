import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/traccar_tracking_data_source.dart';
import '../data/repositories/tracking_repository_impl.dart';
import '../domain/entities/tracking_device.dart';
import '../domain/entities/tracking_event.dart';
import '../domain/entities/tracking_position.dart';
import '../domain/repositories/tracking_repository.dart';

final traccarTrackingDataSourceProvider = Provider<TraccarTrackingDataSource>((
  ref,
) {
  return TraccarTrackingDataSource(ref.watch(backendApiClientProvider), () {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      throw StateError('Sesión inválida o expirada.');
    }
    return session.sessionToken;
  });
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl(ref.watch(traccarTrackingDataSourceProvider));
});

final trackingPositionsProvider =
    AsyncNotifierProvider<TrackingPositionsNotifier, List<TrackingPosition>>(
      TrackingPositionsNotifier.new,
    );

class TrackingPositionsNotifier extends AsyncNotifier<List<TrackingPosition>> {
  @override
  Future<List<TrackingPosition>> build() {
    return ref.watch(trackingRepositoryProvider).getPositions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(trackingRepositoryProvider).getPositions(),
    );
  }
}

final trackingDevicesProvider =
    AsyncNotifierProvider<TrackingDevicesNotifier, List<TrackingDevice>>(
      TrackingDevicesNotifier.new,
    );

class TrackingDevicesNotifier extends AsyncNotifier<List<TrackingDevice>> {
  @override
  Future<List<TrackingDevice>> build() {
    return ref.watch(trackingRepositoryProvider).getDevices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(trackingRepositoryProvider).getDevices(),
    );
  }
}

final trackingEventsProvider =
    AsyncNotifierProvider<TrackingEventsNotifier, List<TrackingEvent>>(
      TrackingEventsNotifier.new,
    );

class TrackingEventsNotifier extends AsyncNotifier<List<TrackingEvent>> {
  @override
  Future<List<TrackingEvent>> build() {
    return ref.watch(trackingRepositoryProvider).getEvents();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(trackingRepositoryProvider).getEvents(),
    );
  }
}
