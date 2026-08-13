class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------------
  // ROLES
  // ---------------------------------------------------------------------------

  static const String adminRole = 'admin';
  static const String supervisorRole = 'supervisor';
  static const String choferRole = 'chofer';
  static const String userRole = 'user';

  // ---------------------------------------------------------------------------
  // NETWORK
  // ---------------------------------------------------------------------------

  static const Duration connectionTimeout =
      Duration(seconds: 15);

  static const Duration receiveTimeout =
      Duration(seconds: 15);

  static const Duration sendTimeout =
      Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // STORAGE KEYS
  // ---------------------------------------------------------------------------

  static const String accessTokenKey =
      'access_token';

  static const String refreshTokenKey =
      'refresh_token';

  static const String sessionKey =
      'fleet_control_session';

  // ---------------------------------------------------------------------------
  // APPLICATION
  // ---------------------------------------------------------------------------

  static const String applicationName =
      'Fleet Control';
}