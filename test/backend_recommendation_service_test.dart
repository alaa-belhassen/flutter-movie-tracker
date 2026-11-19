import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';
import 'package:movietracker/shared/contracts/backend_recommendation_service.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';

void main() {
  test(
    'ranks followed-actor films and excludes already reviewed movies',
    () async {
      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000/api',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/users/me/recommendation-exclusions');
          return http.Response('{"movieIds": []}', 200);
        }),
      );
      final service = BackendRecommendationService(
        movies: FakeMovieRepository(),
        actors: FakeActorRepository(),
        watchlists: FakeWatchlistService(),
        reviewService: FakeReviewService(),
        apiClient: apiClient,
      );

      final recommendations = await service.getRecommendations('user_1');
      final followedActorPick = recommendations.firstWhere(
        (recommendation) => recommendation.movie.id == 'm5',
      );

      expect(followedActorPick.matchScore, greaterThan(80));
      expect(followedActorPick.reason, contains('Liam Vance'));
      expect(
        recommendations.any(
          (recommendation) => recommendation.movie.id == 'm1',
        ),
        isFalse,
      );
      apiClient.close();
    },
  );
}
