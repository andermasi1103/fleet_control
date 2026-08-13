import 'environment.dart';

class AppConfig {
  final Environment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  bool get isProduction => environment.isProduction;

  static const development = AppConfig(
    environment: Environment.development,
    supabaseUrl: 'https://sjwzjuailcteqrkhjqze.supabase.co',
    supabasePublishableKey:
        'sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl',
  );

  static const production = AppConfig(
    environment: Environment.production,
    supabaseUrl: 'https://sjwzjuailcteqrkhjqze.supabase.co',
    supabasePublishableKey:
        'sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl',
  );
}