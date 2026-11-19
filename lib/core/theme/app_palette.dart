import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { cinemaViolet, light }

class AppPalette {
  final Color background;
  final Color surface;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color onPrimary;
  final Color onSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color error;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.onPrimary,
    required this.onSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
  });

  static const cinemaViolet = AppPalette(
    background: Color(0xFF101014),
    surface: Color(0xFF1A1A20),
    border: Color(0xFF292832),
    primary: Color(0xFF32264F),
    secondary: Color(0xFF9995A3),
    onPrimary: Color(0xFFF5F4F7),
    onSecondary: Color(0xFFF5F4F7),
    textPrimary: Color(0xFFF5F4F7),
    textSecondary: Color(0xFF9995A3),
    error: Color(0xFFFF7A7A),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F4F7),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E2EA),
    primary: Color(0xFF32264F),
    secondary: Color(0xFF6D6975),
    onPrimary: Color(0xFFF5F4F7),
    onSecondary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A20),
    textSecondary: Color(0xFF6D6975),
    error: Color(0xFFB3261E),
  );
}

final appThemeModeProvider = StateProvider<AppThemeMode>(
  (ref) => AppThemeMode.cinemaViolet,
);

final appPaletteProvider = Provider<AppPalette>((ref) {
  final mode = ref.watch(appThemeModeProvider);
  switch (mode) {
    case AppThemeMode.cinemaViolet:
      return AppPalette.cinemaViolet;
    case AppThemeMode.light:
      return AppPalette.light;
  }
});
