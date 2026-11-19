import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText = 'See all',
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: textTheme.headlineMedium),
        if (onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionText,
              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
