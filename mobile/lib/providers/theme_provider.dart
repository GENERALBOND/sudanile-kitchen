import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app picks its theme.
enum AppThemeMode { system, light, dark }

/// Holds the user's theme preference and persists it locally.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Whether the theme currently renders dark (system mode follows the OS).
  bool get isDark {
    switch (_mode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null) return;
      final parsed = AppThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (parsed != null) {
        _mode = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Corrupt/missing preference — fall back to system.
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Non-fatal: preference just won't persist.
    }
  }
}