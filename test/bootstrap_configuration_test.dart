import 'package:fleet_control/core/config/app_config.dart';
import 'package:fleet_control/main.dart' as application;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el bootstrap se enlaza con la configuración de Fastify', () {
    expect(application.main, isNotNull);
    expect(AppConfig.development.backendApiBaseUrl, isNotEmpty);
  });
}
