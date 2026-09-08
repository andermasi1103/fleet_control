import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint(
        'push: background message received hasData=${message.data.isNotEmpty}',
      );
    }
  } on FirebaseException catch (error) {
    if (kDebugMode) {
      debugPrint(
        'push: background Firebase initialization failed code=${error.code}',
      );
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        'push: background Firebase initialization failed type=${error.runtimeType}',
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }
    if (kDebugMode) debugPrint('push: Firebase initialized');
  } on FirebaseException catch (error) {
    if (kDebugMode) {
      debugPrint('push: Firebase initialization failed code=${error.code}');
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        'push: Firebase initialization failed type=${error.runtimeType}',
      );
    }
  }

  runApp(const ProviderScope(child: FleetControlApp()));
}
