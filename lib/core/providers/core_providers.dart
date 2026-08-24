import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../network/dio_client.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.development;
});

/// Expone el único cliente creado por `Supabase.initialize` en main.dart.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    config: ref.watch(appConfigProvider),
  );
});

final traccarDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  return ref.watch(dioClientProvider).createTraccarClient(
        baseUrl: config.traccarApiBaseUrl,
        config: config,
      );
});
