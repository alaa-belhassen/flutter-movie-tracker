import 'package:flutter/material.dart';

class SpoilerBanner extends StatefulWidget {
  final Widget child;

  const SpoilerBanner({super.key, required this.child});

  @override
  State<SpoilerBanner> createState() => _SpoilerBannerState();
}

class _SpoilerBannerState extends State<SpoilerBanner> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_revealed) {
      return widget.child;
    }

    return GestureDetector(
      onTap: () => setState(() => _revealed = true),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Spoiler, tap to show',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
