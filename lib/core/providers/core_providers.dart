import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/dio_client.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.development;
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(config: ref.watch(appConfigProvider));
});

final backendDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return ref.watch(dioClientProvider).createBackendClient(config: config);
});

final backendApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(backendDioProvider));
});
