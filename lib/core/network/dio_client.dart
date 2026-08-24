import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class DioClient {
  DioClient({required AppConfig config});

  /// Crea el cliente de Traccar desde el único punto central de configuración.
  /// No incluye encabezados ni tokens de Supabase para evitar filtrarlos a Traccar.
  Dio createTraccarClient({
    required String baseUrl,
    required AppConfig config,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
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
