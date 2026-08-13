import 'dart:developer' as developer;

import 'package:dio/dio.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    developer.log(
      '→ ${options.method} ${options.uri}',
      name: 'Network',
    );

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      name: 'Network',
    );

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    developer.log(
      '✕ ${err.requestOptions.method} '
      '${err.requestOptions.uri} '
      '${err.message}',
      name: 'Network',
    );

    handler.next(err);
  }
}