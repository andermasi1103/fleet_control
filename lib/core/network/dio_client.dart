import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class DioClient {
  DioClient({
    required AppConfig config,
    required AuthInterceptor authInterceptor,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: '${config.supabaseUrl}/rest/v1',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: {
              'apikey': config.supabasePublishableKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(authInterceptor);
    _dio.interceptors.add(ErrorInterceptor());

    if (!config.isProduction) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;

  Dio get instance => _dio;
}