import 'package:flutter/material.dart';

/// Shared brand orange used by the app across both themes.
const Color brandOrange = Color(0xFFFF6A00);

/// Semantic brand colors used by widgets in both themes. Light values mirror
/// the app's existing look; dark values keep the same accents readable on
/// dark surfaces (no more light chips with mid-tone orange text).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Background of small info/tag chips (e.g. a recipe's category tag).
  final Color chipBg;
  /// Foreground text of small info/tag chips.
  final Color chipFg;
  /// Border of outlined chips (e.g. the community "recipe" chip).
  final Color chipBorder;
  /// Background of round icon holders (category/meal icons, avatars).
  final Color iconCircleBg;
  /// Icon/letter color on [iconCircleBg].
  final Color iconCircleFg;
  /// Background of the "Admin" badge.
  final Color dangerChipBg;
  /// Text of the "Admin" badge.
  final Color dangerChipFg;
  /// Profile-header gradient start (top).
  final Color headerGradientTop;
  /// Profile-header gradient end (bottom).
  final Color headerGradientBottom;

  const AppColors({
    required this.chipBg,
    required this.chipFg,
    required this.chipBorder,
    required this.iconCircleBg,
    required this.iconCircleFg,
    required this.dangerChipBg,
    required this.dangerChipFg,
    required this.headerGradientTop,
    required this.headerGradientBottom,
  });

  static const light = AppColors(
    chipBg: Color(0xFFFFF8E1),
    chipFg: Color(0xFFEF6C00),
    chipBorder: Color(0xFFFFCC80),
    iconCircleBg: Color(0xFFFFE0B2),
    iconCircleFg: Color(0xFFEF6C00),
    dangerChipBg: Color(0xFFFFCDD2),
    dangerChipFg: Color(0xFFF44336),
    headerGradientTop: Color(0xFFFFF8E1),
    headerGradientBottom: Colors.white,
  );

  static const dark = AppColors(
    chipBg: Color(0x2AFF6A00),
    chipFg: Color(0xFFFFCC80),
    chipBorder: Color(0xFFEF6C00),
    iconCircleBg: Color(0x2AFF6A00),
    iconCircleFg: Color(0xFFFFB74D),
    dangerChipBg: Color(0x2AF44336),
    dangerChipFg: Color(0xFFEF9A9A),
    headerGradientTop: Color(0xFF2E1A0A),
    headerGradientBottom: Color(0xFF121212),
  );

  @override
  AppColors copyWith({
    Color? chipBg,
    Color? chipFg,
    Color? chipBorder,
    Color? iconCircleBg,
    Color? iconCircleFg,
    Color? dangerChipBg,
    Color? dangerChipFg,
    Color? headerGradientTop,
    Color? headerGradientBottom,
  }) {
    return AppColors(
      chipBg: chipBg ?? this.chipBg,
      chipFg: chipFg ?? this.chipFg,
      chipBorder: chipBorder ?? this.chipBorder,
      iconCircleBg: iconCircleBg ?? this.iconCircleBg,
      iconCircleFg: iconCircleFg ?? this.iconCircleFg,
      dangerChipBg: dangerChipBg ?? this.dangerChipBg,
      dangerChipFg: dangerChipFg ?? this.dangerChipFg,
      headerGradientTop: headerGradientTop ?? this.headerGradientTop,
      headerGradientBottom:
          headerGradientBottom ?? this.headerGradientBottom,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipFg: Color.lerp(chipFg, other.chipFg, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      iconCircleBg: Color.lerp(iconCircleBg, other.iconCircleBg, t)!,
      iconCircleFg: Color.lerp(iconCircleFg, other.iconCircleFg, t)!,
      dangerChipBg: Color.lerp(dangerChipBg, other.dangerChipBg, t)!,
      dangerChipFg: Color.lerp(dangerChipFg, other.dangerChipFg, t)!,
      headerGradientTop:
          Color.lerp(headerGradientTop, other.headerGradientTop, t)!,
      headerGradientBottom:
          Color.lerp(headerGradientBottom, other.headerGradientBottom, t)!,
    );
  }
}

/// Light theme (default) — keeps the app's existing look.
ThemeData buildLightTheme() {
  return ThemeData(
    primarySwatch: Colors.orange,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFFF6F6F6),
    cardColor: Colors.white,
    dividerColor: Colors.black12,
    extensions: const [AppColors.light],
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
    extensions: const [AppColors.dark],
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

/// Convenience accessor for [AppColors] from any widget's [BuildContext].
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}