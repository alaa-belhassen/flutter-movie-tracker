import 'package:flutter/material.dart';

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool isPrimary;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? colorScheme.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textTheme.headlineLarge?.copyWith(
              color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: isPrimary ? colorScheme.onPrimary.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
