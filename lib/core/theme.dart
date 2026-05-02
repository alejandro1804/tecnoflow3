// lib/core/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _primary   = Color(0xFF1565C0);
  static const _secondary = Color(0xFF00897B);
  static const _error     = Color(0xFFC62828);
  static const _bg        = Color(0xFFF4F6F8);
  static const _surface   = Colors.white;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:   _primary,
      secondary: _secondary,
      error:     _error,
      surface:   _surface,
    ),
    scaffoldBackgroundColor: _bg,
    textTheme: const TextTheme(
      bodyLarge:   TextStyle(fontSize: 12),
      bodyMedium:  TextStyle(fontSize: 11),
      bodySmall:   TextStyle(fontSize: 10),
      titleLarge:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      titleSmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelLarge:  TextStyle(fontSize: 12),
      labelMedium: TextStyle(fontSize: 10),
      labelSmall:  TextStyle(fontSize: 10),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDADCE0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDADCE0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: const TextStyle(fontSize: 13),
      hintStyle: const TextStyle(fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontSize: 11),
    ),
  );
}
