class AppConstants {
  // ============================================================
  // ROLES
  // ============================================================

  static const String adminRole = 'admin';

  static const String supervisorRole = 'supervisor';

  static const String choferRole = 'chofer';

  static const String userRole = 'user';

  static const String localRole = 'local';

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
