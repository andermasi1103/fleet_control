import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../data/datasources/notifications_data_source.dart';

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
    if (_started) return;
    if (Firebase.apps.isEmpty) {
      _debug('Firebase unavailable; push startup skipped');
      return;
    }
    _started = true;
    try {
      FirebaseMessaging.onMessage.listen(onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(onNotificationOpened);
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) onNotificationOpened(initialMessage);
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (token) {
              _debug('token refreshed=true');
              unawaited(_registerToken(token));
            },
            onError: (Object error) =>
                _debug('token refresh failed type=${error.runtimeType}'),
          );
      _debug('message handlers started');
    } catch (error) {
      _debug('message handler startup failed type=${error.runtimeType}');
    }
  }

  Future<void> activate(String sessionToken) async {
    _sessionToken = sessionToken;
    if (Firebase.apps.isEmpty) {
      _debug('Firebase unavailable; token registration skipped');
      return;
    }
    try {
      final permission = await FirebaseMessaging.instance.requestPermission();
      final authorized =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      _debug('permission status=${permission.authorizationStatus.name}');
      if (!authorized) {
        _debug(
          'token retrieval skipped; notification permission is not granted',
        );
        return;
      }
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: _config.firebaseVapidPublicKey.isEmpty
                  ? null
                  : _config.firebaseVapidPublicKey,
            )
          : await FirebaseMessaging.instance.getToken();
      _debug('token obtained=${token != null && token.isNotEmpty}');
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      _debug('token activation failed type=${error.runtimeType}');
    }
  }

  Future<void> deactivate(String sessionToken) async {
    final token = _deviceToken;
    _sessionToken = null;
    _deviceToken = null;
    if (token == null || token.isEmpty) return;
    try {
      await _dataSource.unregisterDevice(sessionToken, token);
      _debug('device unregistration succeeded');
    } catch (error) {
      _debug('device unregistration failed type=${error.runtimeType}');
      // Logout is always allowed to continue when offline.
    }
  }

  Future<void> _registerToken(String token) async {
    _deviceToken = token;
    final sessionToken = _sessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      _debug('device registration skipped; no authenticated session');
      return;
    }
    try {
      await _dataSource.registerDevice(
        sessionToken,
        token: token,
        platform: kIsWeb ? 'web' : 'android',
      );
      _debug('device registration succeeded');
    } catch (error) {
      _debug('device registration failed type=${error.runtimeType}');
      // A later refresh/login can retry safely because the backend upserts by token.
    }
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('push: $message');
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
