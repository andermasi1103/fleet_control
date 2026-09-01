import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../data/datasources/notifications_data_source.dart';

/// Firebase remains optional until native/web Firebase configuration is supplied.
/// Every failure is swallowed here so notifications never block MasiTrack.
class PushNotificationService {
  PushNotificationService(this._dataSource, this._config);

  final NotificationsDataSource _dataSource;
  final AppConfig _config;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _sessionToken;
  String? _deviceToken;
  bool _started = false;

  Future<void> start({
    required void Function(RemoteMessage) onForegroundMessage,
    required void Function(RemoteMessage) onNotificationOpened,
  }) async {
    if (_started || Firebase.apps.isEmpty) return;
    _started = true;
    FirebaseMessaging.onMessage.listen(onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(onNotificationOpened);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) onNotificationOpened(initialMessage);
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _registerToken(token),
    );
  }

  Future<void> activate(String sessionToken) async {
    _sessionToken = sessionToken;
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: _config.firebaseVapidPublicKey.isEmpty
                  ? null
                  : _config.firebaseVapidPublicKey,
            )
          : await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Permissions and Firebase setup are best-effort and must not affect login.
    }
  }

  Future<void> deactivate(String sessionToken) async {
    final token = _deviceToken;
    _sessionToken = null;
    _deviceToken = null;
    if (token == null || token.isEmpty) return;
    try {
      await _dataSource.unregisterDevice(sessionToken, token);
    } catch (_) {
      // Logout is always allowed to continue when offline.
    }
  }

  Future<void> _registerToken(String token) async {
    _deviceToken = token;
    final sessionToken = _sessionToken;
    if (sessionToken == null || sessionToken.isEmpty) return;
    try {
      await _dataSource.registerDevice(
        sessionToken,
        token: token,
        platform: kIsWeb ? 'web' : 'android',
      );
    } catch (_) {
      // A later refresh/login can retry safely because the backend upserts by token.
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
