import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'color_schemes.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
  );
}

final themeModeProvider = StateNotifierProvider.autoDispose<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(
    this._ref,
  ) : super(ThemeMode.system);

  final Ref<ThemeMode> _ref;

  void setLightMode() {
    state = ThemeMode.light;
  }

  void setDarkMode() {
    state = ThemeMode.dark;
  }

  void setSystemMode() {
    state = ThemeMode.system;
  }
}
