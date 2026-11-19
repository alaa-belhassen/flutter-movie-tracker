import 'package:flutter/material.dart';
import 'stat_tile.dart';

class IndicatorRow extends StatelessWidget {
  final List<Map<String, String>> stats; // [{value, label}, ...]

  const IndicatorRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stats.length, (index) {
        final stat = stats[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < stats.length - 1 ? 8.0 : 0.0),
            child: StatTile(
              value: stat['value'] ?? '',
              label: stat['label'] ?? '',
              isPrimary: index == 0,
            ),
          ),
        );
      }),
    );
  }
}
