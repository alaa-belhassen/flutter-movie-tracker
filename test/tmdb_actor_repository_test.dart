import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';
import 'package:movietracker/shared/contracts/tmdb_actor_repository.dart';

void main() {
  test('follows and unfollows actors through the authenticated API', () async {
    var followed = false;
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:3000/api',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/users/me/actors');
          return http.Response(
            '{"actorIds": ${followed ? '["actor_1"]' : '[]'}}',
            200,
          );
        }
        if (request.method == 'PUT') {
          expect(request.url.path, '/api/users/me/actors/actor_1');
          followed = true;
          return http.Response('', 204);
        }
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/users/me/actors/actor_1');
        followed = false;
        return http.Response('', 204);
      }),
    );
    final repository = TmdbActorRepository(FakeMovieRepository(), apiClient);

    await repository.toggleFollowActor('user-1', 'actor_1');
    expect(await repository.getFollowedActorIds('user-1'), ['actor_1']);
    await repository.toggleFollowActor('user-1', 'actor_1');
    expect(await repository.getFollowedActorIds('user-1'), isEmpty);
    apiClient.close();
  });
}
