import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState extends ChangeNotifier {
  static const _themePreferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    final prefs = await _preferences;
    final storedTheme = prefs.getString(_themePreferenceKey);
    final resolvedTheme = _themeModeFromString(storedTheme);
    if (resolvedTheme != _themeMode) {
      _themeMode = resolvedTheme;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    final prefs = await _preferences;
    await prefs.setString(_themePreferenceKey, _themeMode.name);
    notifyListeners();
  }

  Future<SharedPreferences> get _preferences async {
    final cached = _prefs;
    if (cached != null) {
      return cached;
    }

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}
