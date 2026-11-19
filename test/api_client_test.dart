import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';

void main() {
  test('explains how to fix an unreachable API', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:3000/api',
      client: MockClient((request) async {
        throw http.ClientException('Failed to fetch', request.url);
      }),
    );

    await expectLater(
      client.request('GET', 'auth/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 0)
            .having(
              (error) => error.message,
              'message',
              allOf(
                contains('http://localhost:3000/api'),
                contains('npm start'),
                contains('CORS_ORIGINS'),
              ),
            ),
      ),
    );
    client.close();
  });
}
