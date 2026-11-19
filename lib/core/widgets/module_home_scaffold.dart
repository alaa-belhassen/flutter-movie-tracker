import 'package:flutter/material.dart';

import 'indicator_row.dart';

class ModuleHomeScaffold extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Map<String, String>> indicators;
  final List<Widget> featureTiles;
  final String mainButtonText;
  final VoidCallback onMainButtonPressed;

  const ModuleHomeScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.indicators,
    required this.featureTiles,
    required this.mainButtonText,
    required this.onMainButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(icon, color: colorScheme.secondary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            IndicatorRow(stats: indicators),
            const SizedBox(height: 24),
            ...featureTiles,
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onMainButtonPressed,
              child: Text(mainButtonText),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
