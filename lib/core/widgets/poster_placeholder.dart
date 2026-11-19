import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PosterPlaceholder extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final String? imagePath;

  const PosterPlaceholder({
    super.key,
    required this.title,
    this.width,
    this.height,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = title.isNotEmpty
        ? title
              .split(' ')
              .take(2)
              .map((e) => e.isNotEmpty ? e[0] : '')
              .join()
              .toUpperCase()
        : 'MV';

    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.primary.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    final path = imagePath;
    if (path == null || path.isEmpty) return fallback;

    final imageUrl = Uri.https(
      'image.tmdb.org',
      '/t/p/w500${path.startsWith('/') ? path : '/$path'}',
    ).toString();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}
