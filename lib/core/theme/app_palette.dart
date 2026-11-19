import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { cinemaRed, light }

class AppPalette {
  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color error;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
  });

  static const cinemaRed = AppPalette(
    background: Color(0xFF10131A),
    surface: Color(0xFF191E28),
    primary: Color(0xFFFF6B6B),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFADB5C4),
    error: Color(0xFFFF6B6B),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFD94F5C),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF171A22),
    textSecondary: Color(0xFF697080),
    error: Color(0xFFD94F5C),
  );
}

final appThemeModeProvider = StateProvider<AppThemeMode>(
  (ref) => AppThemeMode.cinemaRed,
);

final appPaletteProvider = Provider<AppPalette>((ref) {
  final mode = ref.watch(appThemeModeProvider);
  switch (mode) {
    case AppThemeMode.cinemaRed:
      return AppPalette.cinemaRed;
    case AppThemeMode.light:
      return AppPalette.light;
  }
});
