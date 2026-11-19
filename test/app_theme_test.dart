import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movietracker/core/theme/app_palette.dart';
import 'package:movietracker/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cinema palette uses the supplied violet and charcoal colors', () {
    final theme = AppTheme.buildTheme(AppPalette.cinemaViolet);

    expect(theme.scaffoldBackgroundColor, const Color(0xFF101014));
    expect(theme.colorScheme.surface, const Color(0xFF1A1A20));
    expect(theme.colorScheme.outline, const Color(0xFF292832));
    expect(theme.colorScheme.primary, const Color(0xFF32264F));
    expect(theme.colorScheme.secondary, const Color(0xFF9995A3));
    expect(theme.colorScheme.onSurface, const Color(0xFFF5F4F7));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF9995A3));
    expect(theme.textTheme.headlineLarge?.fontFamily, startsWith('Inter'));
    expect(theme.textTheme.headlineLarge?.fontSize, 28);
    expect(theme.textTheme.headlineMedium?.fontSize, 20);
    expect(theme.textTheme.titleMedium?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 13);
  });
}
