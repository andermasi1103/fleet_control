import 'environment.dart';

class AppConfig {
  final Environment environment;
  final String backendApiBaseUrl;
  final String firebaseVapidPublicKey;

  const AppConfig({
    required this.environment,
    required this.backendApiBaseUrl,
    required this.firebaseVapidPublicKey,
  });

  bool get isProduction => environment.isProduction;

  static const development = AppConfig(
    environment: Environment.development,
    backendApiBaseUrl: String.fromEnvironment(
      'BACKEND_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    ),
    firebaseVapidPublicKey: String.fromEnvironment('FIREBASE_VAPID_PUBLIC_KEY'),
  );

  static const production = AppConfig(
    environment: Environment.production,
    backendApiBaseUrl: String.fromEnvironment(
      'BACKEND_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    ),
    firebaseVapidPublicKey: String.fromEnvironment('FIREBASE_VAPID_PUBLIC_KEY'),
  );
}
