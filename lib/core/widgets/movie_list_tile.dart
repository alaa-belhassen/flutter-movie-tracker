import 'package:flutter/material.dart';

import 'poster_placeholder.dart';
import 'rating_stars.dart';

class MovieListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double rating;
  final VoidCallback onTap;
  final VoidCallback? onBookmarkToggle;
  final bool isBookmarked;
  final String? posterPath;

  const MovieListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.onTap,
    this.onBookmarkToggle,
    this.isBookmarked = false,
    this.posterPath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 72,
            child: PosterPlaceholder(title: title, imagePath: posterPath),
          ),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            RatingStars(rating: rating, size: 14),
          ],
        ),
        trailing: onBookmarkToggle != null
            ? IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: colorScheme.primary,
                ),
                onPressed: onBookmarkToggle,
              )
            : null,
      ),
    );
  }
}
