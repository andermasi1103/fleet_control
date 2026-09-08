import 'package:flutter/services.dart';

import '../domain/tracking_profile.dart';

/// Runtime-only data required by the Android foreground location service.
///
/// The session token is deliberately passed in memory through an explicit,
/// non-exported Android service. It is never persisted or logged by Flutter.
class NativeDriverTrackingStartRequest {
  const NativeDriverTrackingStartRequest({
    required this.sessionToken,
    required this.backendApiBaseUrl,
    required this.profile,
  });

  final String sessionToken;
  final String backendApiBaseUrl;
  final TrackingProfile profile;

  Map<String, Object> toMethodArguments() => {
    'sessionToken': sessionToken,
    'backendApiBaseUrl': backendApiBaseUrl,
    'profile': profile.name,
  };
}

class NativeDriverTrackingProfileUpdate {
  const NativeDriverTrackingProfileUpdate(this.profile);

  final TrackingProfile profile;

  Map<String, Object> toMethodArguments() => {'profile': profile.name};
}

enum NativeDriverTrackingStatus { idle, starting, active, error }

class NativeDriverTrackingState {
  const NativeDriverTrackingState({
    required this.status,
    this.profile = TrackingProfile.idle,
    this.message,
  });

  const NativeDriverTrackingState.idle()
    : this(status: NativeDriverTrackingStatus.idle);

  final NativeDriverTrackingStatus status;
  final TrackingProfile profile;
  final String? message;

  bool get isActive => status == NativeDriverTrackingStatus.active;
}

abstract interface class NativeDriverTrackingGateway {
  Future<NativeDriverTrackingState> start(
    NativeDriverTrackingStartRequest request,
  );

  Future<void> stop();

  Future<NativeDriverTrackingState> updateProfile(
    NativeDriverTrackingProfileUpdate update,
  );

  Future<NativeDriverTrackingState> getStatus();
}

class MethodChannelNativeDriverTrackingGateway
    implements NativeDriverTrackingGateway {
  const MethodChannelNativeDriverTrackingGateway({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const _defaultChannel = MethodChannel('masitrack/driver_tracking');

  final MethodChannel _channel;

  @override
  Future<NativeDriverTrackingState> start(
    NativeDriverTrackingStartRequest request,
  ) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'startTracking',
      request.toMethodArguments(),
    );
    return _stateFromResult(result);
  }

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stopTracking');

  @override
  Future<NativeDriverTrackingState> updateProfile(
    NativeDriverTrackingProfileUpdate update,
  ) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'updateProfile',
      update.toMethodArguments(),
    );
    return _stateFromResult(result);
  }

  @override
  Future<NativeDriverTrackingState> getStatus() async {
    final result = await _channel.invokeMapMethod<String, Object?>('getStatus');
    return _stateFromResult(result);
  }

  NativeDriverTrackingState _stateFromResult(Map<String, Object?>? result) {
    final status = switch (result?['status']) {
      'starting' => NativeDriverTrackingStatus.starting,
      'active' => NativeDriverTrackingStatus.active,
      'error' => NativeDriverTrackingStatus.error,
      _ => NativeDriverTrackingStatus.idle,
    };
    final profile = switch (result?['profile']) {
      'available' => TrackingProfile.available,
      'activeTrip' => TrackingProfile.activeTrip,
      _ => TrackingProfile.idle,
    };
    final message = result?['message'];
    return NativeDriverTrackingState(
      status: status,
      profile: profile,
      message: message is String && message.isNotEmpty ? message : null,
    );
  }
}
