import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';
import 'package:movietracker/shared/contracts/backend_watchlist_service.dart';

void main() {
  test(
    'adds a favorite immediately and keeps it during list refresh',
    () async {
      final client = ApiClient(
        baseUrl: 'http://localhost:3000/api',
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            expect(request.url.path, '/api/users/me/favorites/603');
            return http.Response('', 204);
          }
          expect(request.method, 'GET');
          expect(request.url.path, '/api/users/me/favorites');
          return http.Response('{"movieIds": ["550"]}', 200);
        }),
      );
      final service = BackendWatchlistService(client);

      await service.addFavorite('user-1', '603');
      final favorites = await service.getFavorites('user-1');

      expect(favorites, containsAll(['550', '603']));
      client.close();
    },
  );
}
