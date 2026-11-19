class Review {
  final String id;
  final String movieId;
  final String userId;
  final String userNickname;
  final double rating;
  final String content;
  final bool containsSpoiler;
  final bool isRewatch;
  final int helpfulCount;
  final DateTime timestamp;

  const Review({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.userNickname,
    required this.rating,
    required this.content,
    required this.containsSpoiler,
    required this.isRewatch,
    this.helpfulCount = 0,
    required this.timestamp,
  });
}

class ViewingEntry {
  const ViewingEntry({
    required this.id,
    required this.movieId,
    required this.watchedAt,
    this.rating,
    required this.isRewatch,
    required this.notes,
  });

  final String id;
  final String movieId;
  final DateTime watchedAt;
  final double? rating;
  final bool isRewatch;
  final String notes;
}

abstract class ReviewService {
  Future<List<Review>> getReviewsForMovie(String movieId);
  Future<List<Review>> getUserReviews(String userId);
  Future<Review?> getUserReviewForMovie(String userId, String movieId);
  Future<void> saveReview(Review review);
  Future<void> deleteReview(String reviewId);
  Future<void> markHelpful(String reviewId);
  Future<Map<String, dynamic>> getUserStats(String userId);
  Future<List<ViewingEntry>> getViewingEntries(String userId);
  Future<ViewingEntry> logViewing({
    required String movieId,
    required DateTime watchedAt,
    double? rating,
    required bool isRewatch,
    required String notes,
  });
  Future<void> deleteViewingEntry(String entryId);
}
