import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movietracker/shared/contracts/api_client.dart';
import 'package:movietracker/shared/contracts/backend_forum_service.dart';
import 'package:movietracker/shared/contracts/forum_service.dart';

void main() {
  test(
    'loads persisted discussion topics from the authenticated API',
    () async {
      final client = ApiClient(
        baseUrl: 'http://localhost:3000/api',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/forum/topics');
          expect(request.headers['Authorization'], 'Bearer session-token');
          return http.Response(
            jsonEncode({
              'topics': [
                {
                  'id': 'topic-1',
                  'title': 'A thoughtful discussion',
                  'movieId': null,
                  'authorId': 'user-1',
                  'authorNickname': 'Alice',
                  'replyCount': 3,
                  'timestamp': '2026-11-19T13:00:00.000Z',
                  'isHidden': false,
                },
              ],
            }),
            200,
          );
        }),
      )..accessToken = 'session-token';
      final service = BackendForumService(client);

      final topics = await service.getTopics();

      expect(topics, hasLength(1));
      expect(topics.single.title, 'A thoughtful discussion');
      expect(topics.single.replyCount, 3);
      client.close();
    },
  );

  test(
    'reports a message without trusting client supplied author data',
    () async {
      final client = ApiClient(
        baseUrl: 'http://localhost:3000/api',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/forum/reports');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'targetType': 'message',
            'targetId': 'message-1',
            'reason': 'Please review this message.',
          });
          return http.Response(jsonEncode({'reportId': 'report-1'}), 201);
        }),
      )..accessToken = 'session-token';
      final service = BackendForumService(client);

      await service.reportMessage(
        'message-1',
        'untrusted client excerpt',
        'Please review this message.',
        'untrusted reporter id',
      );

      client.close();
    },
  );

  test('maps anti-spam responses to a rejected post', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:3000/api',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'You can post at most 5 messages per minute.'}),
          429,
        ),
      ),
    )..accessToken = 'session-token';
    final service = BackendForumService(client);
    final message = ForumMessage(
      id: '',
      topicId: 'topic-1',
      userId: 'user-1',
      userNickname: 'Alice',
      content: 'Hello, forum.',
      timestamp: DateTime.utc(2026, 11, 19),
    );

    expect(
      await service.postMessage(message, userMessageCountLastMinute: 0),
      isFalse,
    );
    client.close();
  });
}
