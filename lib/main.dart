import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native/web Firebase options are supplied outside source control. A missing
  // configuration leaves push disabled but does not prevent Fleet Control from starting.
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  runApp(const ProviderScope(child: FleetControlApp()));
}
