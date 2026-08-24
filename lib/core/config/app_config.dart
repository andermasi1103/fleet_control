import 'environment.dart';

class AppConfig {
  static const _supabaseUrl = 'https://sjwzjuailcteqrkhjqze.supabase.co';
  static const _supabasePublishableKey =
      'sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl';

  final Environment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String traccarApiBaseUrl;
  final String traccarAuthorization;

  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.traccarApiBaseUrl,
    required this.traccarAuthorization,
  });

  bool get isProduction => environment.isProduction;

  static const development = AppConfig(
    environment: Environment.development,
    supabaseUrl: _supabaseUrl,
    supabasePublishableKey: _supabasePublishableKey,
    traccarApiBaseUrl: String.fromEnvironment(
      'TRACCAR_API_BASE_URL',
      defaultValue: 'https://traccar.example.com/api',
    ),
    // Debe contener el valor completo del header Authorization. Por ejemplo:
    // --dart-define=TRACCAR_AUTHORIZATION="Bearer <token>"
    traccarAuthorization: String.fromEnvironment('TRACCAR_AUTHORIZATION'),
  );

  static const production = AppConfig(
    environment: Environment.production,
    supabaseUrl: _supabaseUrl,
    supabasePublishableKey: _supabasePublishableKey,
    traccarApiBaseUrl: String.fromEnvironment(
      'TRACCAR_API_BASE_URL',
      defaultValue: 'https://traccar.example.com/api',
    ),
    traccarAuthorization: String.fromEnvironment('TRACCAR_AUTHORIZATION'),
  );
}
