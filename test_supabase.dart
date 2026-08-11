import 'dart:developer' as developer;
import 'package:dio/dio.dart';

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: "https://sjwzjuailcteqrkhjqze.supabase.co/rest/v1/",
      headers: {
        "apikey": "sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl",
        "Authorization": "Bearer sb_publishable_2-bfhvSw_OIu3J1WCbFbOw_CKf9Idwl",
      },
    ),
  );

  // 🔹 Prueba 1: traer todo
  final all = await dio.get("FleetControl", queryParameters: {"select": "*"});
  developer.log("➡️ Todos los registros: ${all.data}", name: "TestSupabase");

  // 🔹 Prueba 2: filtrar solo por usuario
  final byUser = await dio.get("FleetControl", queryParameters: {
    "select": "*",
    "usuario": "eq.admin",
  });
  developer.log("➡️ Filtro usuario=admin: ${byUser.data}", name: "TestSupabase");

  // 🔹 Prueba 3: filtrar solo por password
  final byPass = await dio.get("FleetControl", queryParameters: {
    "select": "*",
    "password": "eq.1234",
  });
  developer.log("➡️ Filtro password=1234: ${byPass.data}", name: "TestSupabase");

  // 🔹 Prueba 4: filtrar usuario+password
  final byBoth = await dio.get("FleetControl", queryParameters: {
    "select": "*",
    "usuario": "eq.admin",
    "password": "eq.1234",
  });
  developer.log("➡️ Filtro usuario=admin & password=1234: ${byBoth.data}", name: "TestSupabase");
}
