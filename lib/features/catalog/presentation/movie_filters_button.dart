import 'package:flutter/material.dart';

class MovieFiltersButton extends StatelessWidget {
  const MovieFiltersButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.tune_rounded, size: 19),
      label: Text(activeCount == 0 ? 'Filters' : 'Filters $activeCount'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
