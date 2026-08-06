import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xff1565C0);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: Colors.grey.shade100,

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}