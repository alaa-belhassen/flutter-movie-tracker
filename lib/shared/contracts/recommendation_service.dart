import 'movie_repository.dart';

class RecommendedMovie {
  final Movie movie;
  final int matchScore; // e.g. 95%
  final String reason; // e.g. "You rated 5 stars..."

  const RecommendedMovie({
    required this.movie,
    required this.matchScore,
    required this.reason,
  });
}

abstract class RecommendationService {
  Future<List<RecommendedMovie>> getRecommendations(String userId);
  Future<void> excludeRecommendation(String userId, String movieId);
}
