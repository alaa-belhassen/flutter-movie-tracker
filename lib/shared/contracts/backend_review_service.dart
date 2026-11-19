import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'review_service.dart';

class BackendReviewService implements ReviewService {
  BackendReviewService(this._apiClient);

  final ApiClient _apiClient;

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String key) {
    final value = response[key];
    if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
      throw FormatException('The API returned invalid $key.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  Review _reviewFromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    if (rating is! num ||
        json['id'] is! String ||
        json['movieId'] is! String ||
        json['userId'] is! String ||
        json['userNickname'] is! String ||
        json['content'] is! String ||
        json['containsSpoiler'] is! bool ||
        json['isRewatch'] is! bool ||
        json['timestamp'] is! String) {
      throw const FormatException('The API returned an invalid review.');
    }
    final timestamp = DateTime.tryParse(json['timestamp'] as String);
    if (timestamp == null) {
      throw const FormatException('The API returned an invalid review date.');
    }
    final helpfulCount = json['helpfulCount'];
    return Review(
      id: json['id'] as String,
      movieId: json['movieId'] as String,
      userId: json['userId'] as String,
      userNickname: json['userNickname'] as String,
      rating: rating.toDouble(),
      content: json['content'] as String,
      containsSpoiler: json['containsSpoiler'] as bool,
      isRewatch: json['isRewatch'] as bool,
      helpfulCount: helpfulCount is int ? helpfulCount : 0,
      timestamp: timestamp,
    );
  }

  ViewingEntry _entryFromJson(Map<String, dynamic> json) {
    final watchedAtValue = json['watchedAt'];
    final watchedAt = watchedAtValue is String
        ? DateTime.tryParse(watchedAtValue)
        : null;
    final rating = json['rating'];
    if (json['id'] is! String ||
        json['movieId'] is! String ||
        watchedAt == null ||
        (rating != null && rating is! num) ||
        json['isRewatch'] is! bool ||
        json['notes'] is! String) {
      throw const FormatException('The API returned an invalid viewing entry.');
    }
    return ViewingEntry(
      id: json['id'] as String,
      movieId: json['movieId'] as String,
      watchedAt: watchedAt,
      rating: rating is num ? rating.toDouble() : null,
      isRewatch: json['isRewatch'] as bool,
      notes: json['notes'] as String,
    );
  }

  @override
  Future<List<Review>> getReviewsForMovie(String movieId) async {
    final response = await _apiClient.request(
      'GET',
      'movies/${Uri.encodeComponent(movieId)}/reviews',
      authenticated: false,
    );
    return _rows(response, 'reviews').map(_reviewFromJson).toList();
  }

  @override
  Future<List<Review>> getUserReviews(String userId) async {
    final response = await _apiClient.request('GET', 'users/me/reviews');
    return _rows(response, 'reviews').map(_reviewFromJson).toList();
  }

  @override
  Future<Review?> getUserReviewForMovie(String userId, String movieId) async {
    final response = await _apiClient.request(
      'GET',
      'users/me/reviews/${Uri.encodeComponent(movieId)}',
    );
    final value = response['review'];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid review.');
    }
    return _reviewFromJson(value);
  }

  @override
  Future<void> saveReview(Review review) async {
    await _apiClient.request(
      'PUT',
      'users/me/reviews/${Uri.encodeComponent(review.movieId)}',
      body: {
        'rating': review.rating,
        'content': review.content,
        'containsSpoiler': review.containsSpoiler,
        'isRewatch': review.isRewatch,
      },
    );
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    await _apiClient.request(
      'DELETE',
      'users/me/reviews/${Uri.encodeComponent(reviewId)}',
    );
  }

  @override
  Future<void> markHelpful(String reviewId) async {
    await _apiClient.request(
      'POST',
      'reviews/${Uri.encodeComponent(reviewId)}/helpful',
      body: const {},
    );
  }

  @override
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final response = await _apiClient.request('GET', 'users/me/stats');
    final stats = response['stats'];
    if (stats is! Map<String, dynamic>) {
      throw const FormatException('The API returned invalid user statistics.');
    }
    return stats;
  }

  @override
  Future<List<ViewingEntry>> getViewingEntries(String userId) async {
    final response = await _apiClient.request('GET', 'users/me/journal');
    return _rows(response, 'entries').map(_entryFromJson).toList();
  }

  @override
  Future<ViewingEntry> logViewing({
    required String movieId,
    required DateTime watchedAt,
    double? rating,
    required bool isRewatch,
    required String notes,
  }) async {
    final response = await _apiClient.request(
      'POST',
      'users/me/journal',
      body: {
        'movieId': movieId,
        'watchedAt': watchedAt.toUtc().toIso8601String(),
        'rating': rating,
        'isRewatch': isRewatch,
        'notes': notes,
      },
    );
    final entry = response['entry'];
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid viewing entry.');
    }
    return _entryFromJson(entry);
  }

  @override
  Future<void> deleteViewingEntry(String entryId) async {
    await _apiClient.request(
      'DELETE',
      'users/me/journal/${Uri.encodeComponent(entryId)}',
    );
  }
}

final backendReviewServiceProvider = Provider<ReviewService>(
  (ref) => BackendReviewService(ref.watch(apiClientProvider)),
);
