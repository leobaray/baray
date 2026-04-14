import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

Future<ThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  return switch (prefs.getString(_prefsKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });
}
