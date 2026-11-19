import 'package:flutter/material.dart';

class RatingBar extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final double size;

  const RatingBar({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onRatingChanged != null
                  ? () => onRatingChanged!(index + 0.5)
                  : null,
              child: Icon(
                rating >= index + 0.5
                    ? (rating >= index + 1 ? Icons.star : Icons.star_half)
                    : Icons.star_border,
                color: colorScheme.secondary,
                size: size,
              ),
            ),
          ],
        );
      }),
    );
  }
}
