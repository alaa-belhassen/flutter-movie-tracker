import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Dark Mode (Cinema Red)'),
            value: themeMode == AppThemeMode.cinemaRed,
            onChanged: (val) {
              ref.read(appThemeModeProvider.notifier).state = val ? AppThemeMode.cinemaRed : AppThemeMode.light;
            },
          ),
          const Divider(height: 32),
          Text('Language & Region', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Language'),
            trailing: const Text('English (EN)'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Country'),
            trailing: const Text('United States (US)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
