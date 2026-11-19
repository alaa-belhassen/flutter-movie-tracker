import 'package:flutter/material.dart';

import 'poster_placeholder.dart';
import 'rating_stars.dart';

class MoviePosterCard extends StatelessWidget {
  final String title;
  final double rating;
  final VoidCallback onTap;
  final double width;
  final String? posterPath;

  const MoviePosterCard({
    super.key,
    required this.title,
    required this.rating,
    required this.onTap,
    this.width = 120,
    this.posterPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PosterPlaceholder(
                      title: title,
                      imagePath: posterPath,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                RatingStars(rating: rating, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
