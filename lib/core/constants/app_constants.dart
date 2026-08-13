class AppConstants {
  // ============================================================
  // SUPABASE
  // ============================================================

  static const String apiUrl =
      'https://sjwzjuailcteqrkhjqze.supabase.co';

  static const String apiKey =
      'sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl';

  // ============================================================
  // ROLES
  // ============================================================

  static const String adminRole = 'admin';

  static const String supervisorRole = 'supervisor';

  static const String choferRole = 'chofer';

  static const String userRole = 'user';

  // ============================================================
  // APP
  // ============================================================

  static const String version = '1.0.0';

  // ============================================================
  // NETWORK
  // ============================================================

  static const Duration connectionTimeout =
      Duration(seconds: 10);

  static const Duration receiveTimeout =
      Duration(seconds: 10);
}