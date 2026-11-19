import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating; // 0 to 5
  final double size;

  const RatingStars({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (rating >= index + 1) {
          icon = Icons.star;
        } else if (rating >= index + 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: colorScheme.secondary, size: size);
      }),
    );
  }
}
