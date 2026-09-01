import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class DioClient {
  DioClient({required AppConfig config});

  /// Cliente único para los endpoints de MasiTrack API.
  Dio createBackendClient({required AppConfig config}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.backendApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _addInterceptors(dio, config);
    return dio;
  }

  void _addInterceptors(Dio dio, AppConfig config) {
    dio.interceptors.add(ErrorInterceptor());

    if (!config.isProduction) {
      dio.interceptors.add(LoggingInterceptor());
    }
  }
}
