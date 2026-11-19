import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';
import 'package:movietracker/shared/contracts/backend_review_service.dart';

void main() {
  test('loads public reviews and maps API fields', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:3000/api',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/movies/603/reviews');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'id': 'review-1',
                'movieId': '603',
                'userId': 'user-1',
                'userNickname': 'Alice',
                'rating': 4.5,
                'content': 'Excellent.',
                'containsSpoiler': false,
                'isRewatch': true,
                'helpfulCount': 2,
                'timestamp': '2025-03-01T20:00:00.000Z',
              },
            ],
          }),
          200,
        );
      }),
    );
    final service = BackendReviewService(client);

    final reviews = await service.getReviewsForMovie('603');

    expect(reviews, hasLength(1));
    expect(reviews.single.userNickname, 'Alice');
    expect(reviews.single.rating, 4.5);
    expect(reviews.single.isRewatch, isTrue);
    expect(reviews.single.helpfulCount, 2);
    client.close();
  });

  test('saves a viewing using the authenticated journal endpoint', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:3000/api',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/users/me/journal');
        expect(request.headers['Authorization'], 'Bearer session-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['movieId'], '603');
        expect(body['rating'], 4.5);
        expect(body['isRewatch'], isTrue);
        return http.Response(
          jsonEncode({
            'entry': {
              'id': 'entry-1',
              'movieId': '603',
              'watchedAt': '2025-03-01T20:00:00.000Z',
              'rating': 4.5,
              'isRewatch': true,
              'notes': 'Great rewatch.',
            },
          }),
          201,
        );
      }),
    )..accessToken = 'session-token';
    final service = BackendReviewService(client);

    final entry = await service.logViewing(
      movieId: '603',
      watchedAt: DateTime.utc(2025, 3, 1, 20),
      rating: 4.5,
      isRewatch: true,
      notes: 'Great rewatch.',
    );

    expect(entry.id, 'entry-1');
    expect(entry.movieId, '603');
    expect(entry.rating, 4.5);
    expect(entry.isRewatch, isTrue);
    client.close();
  });
}
