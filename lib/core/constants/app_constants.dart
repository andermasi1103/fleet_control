class AppConstants {
  // 🔹 API Supabase
  static const apiUrl = "https://sjwzjuailcteqrkhjqze.supabase.co";
  static const apiKey = "sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl";

  // 🔹 Roles
  static const String adminRole = 'admin';
  static const String supervisorRole = 'supervisor';
  static const String choferRole = 'chofer';
  static const String userRole = 'user';

  // 🔹 Version de la app (para login_footer.dart)
  static const version = "1.0.0";

  // 🔹 Timeouts
  static const connectionTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 10);
}
