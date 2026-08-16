import 'package:flutter/material.dart';

/// Shared brand orange used by the app across both themes.
const Color brandOrange = Color(0xFFFF6A00);

/// Light theme (default) — keeps the app's existing look.
ThemeData buildLightTheme() {
  return ThemeData(
    primarySwatch: Colors.orange,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFFF6F6F6),
    cardColor: Colors.white,
    dividerColor: Colors.black12,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.grey,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Dark theme.
ThemeData buildDarkTheme() {
  const surface = Color(0xFF121212);
  const surfaceRaised = Color(0xFF1E1E1E);
  const onSurface = Color(0xFFECECEC);
  const onSurfaceMuted = Color(0xFF9E9E9E);

  return ThemeData(
    primarySwatch: Colors.orange,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: surface,
    cardColor: surfaceRaised,
    dividerColor: Colors.white12,
    colorScheme: const ColorScheme.dark(
      primary: Colors.orange,
      secondary: Colors.orangeAccent,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceMuted,
      outline: Colors.white24,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: onSurface),
      bodySmall: TextStyle(color: onSurfaceMuted),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: surfaceRaised,
      foregroundColor: onSurface,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceRaised,
      selectedItemColor: Colors.orange,
      unselectedItemColor: onSurfaceMuted,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: const DialogThemeData(backgroundColor: surfaceRaised),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceRaised,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      labelStyle: TextStyle(color: onSurfaceMuted),
    ),
  );
}