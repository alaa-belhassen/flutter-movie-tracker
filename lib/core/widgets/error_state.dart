import 'package:flutter/material.dart';

enum ErrorVariant { offline, noResult, quotaExceeded }

class ErrorState extends StatelessWidget {
  final ErrorVariant variant;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.variant, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String message;
    IconData icon;
    switch (variant) {
      case ErrorVariant.offline:
        message = 'You are offline. Check your connection.';
        icon = Icons.wifi_off;
        break;
      case ErrorVariant.noResult:
        message = 'No results found.';
        icon = Icons.search_off;
        break;
      case ErrorVariant.quotaExceeded:
        message = 'API quota exceeded. Please try later.';
        icon = Icons.warning;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
