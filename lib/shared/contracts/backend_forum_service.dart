import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'forum_service.dart';

class BackendForumService implements ForumService {
  BackendForumService(this._apiClient);

  final ApiClient _apiClient;

  List<Map<String, dynamic>> _list(Map<String, dynamic> response, String key) {
    final value = response[key];
    if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
      throw FormatException('The API returned invalid $key.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  DateTime _date(Object? value) {
    if (value is! String) {
      throw const FormatException('The API returned an invalid date.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw const FormatException('The API returned an invalid date.');
    }
    return date;
  }

  ForumTopic _topic(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['title'] is! String ||
        row['authorId'] is! String ||
        row['authorNickname'] is! String) {
      throw const FormatException('The API returned an invalid topic.');
    }
    return ForumTopic(
      id: row['id'] as String,
      title: row['title'] as String,
      movieId: row['movieId'] as String?,
      authorId: row['authorId'] as String,
      authorNickname: row['authorNickname'] as String,
      replyCount: row['replyCount'] as int? ?? 0,
      timestamp: _date(row['timestamp']),
      isHidden: row['isHidden'] == true,
    );
  }

  ForumMessage _message(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['topicId'] is! String ||
        row['userId'] is! String ||
        row['userNickname'] is! String ||
        row['content'] is! String) {
      throw const FormatException('The API returned an invalid message.');
    }
    return ForumMessage(
      id: row['id'] as String,
      topicId: row['topicId'] as String,
      userId: row['userId'] as String,
      userNickname: row['userNickname'] as String,
      isModerator: row['isModerator'] == true,
      content: row['content'] as String,
      likeCount: row['likeCount'] as int? ?? 0,
      timestamp: _date(row['timestamp']),
      isDeleted: row['isDeleted'] == true,
    );
  }

  ForumReport _reportFromJson(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['targetId'] is! String ||
        row['targetExcerpt'] is! String ||
        row['reason'] is! String) {
      throw const FormatException('The API returned an invalid report.');
    }
    return ForumReport(
      id: row['id'] as String,
      targetId: row['targetId'] as String,
      targetExcerpt: row['targetExcerpt'] as String,
      reason: row['reason'] as String,
      reporterId: '',
      reportCount: row['reportCount'] as int? ?? 1,
      status: row['status'] as String? ?? 'pending',
      timestamp: _date(row['timestamp']),
      targetType: row['targetType'] as String? ?? 'message',
      targetAuthorId: row['targetAuthorId'] as String? ?? '',
      targetAuthorNickname: row['targetAuthorNickname'] as String? ?? '',
      reporterNicknames: row['reporterNicknames'] as String? ?? '',
    );
  }

  ForumRestriction _restriction(Map<String, dynamic> row) {
    if (row['id'] is! String ||
        row['userId'] is! String ||
        row['userNickname'] is! String ||
        row['reason'] is! String) {
      throw const FormatException('The API returned an invalid restriction.');
    }
    return ForumRestriction(
      id: row['id'] as String,
      userId: row['userId'] as String,
      userNickname: row['userNickname'] as String,
      reason: row['reason'] as String,
      timestamp: _date(row['timestamp']),
    );
  }

  @override
  Future<List<ForumTopic>> getTopics({String? movieId}) async {
    final path = movieId == null
        ? 'forum/topics'
        : 'forum/topics?movieId=${Uri.encodeQueryComponent(movieId)}';
    final response = await _apiClient.request('GET', path);
    return _list(response, 'topics').map(_topic).toList(growable: false);
  }

  @override
  Future<ForumTopic?> getTopicById(String id) async {
    final response = await _apiClient.request(
      'GET',
      'forum/topics/${Uri.encodeComponent(id)}',
    );
    final topic = response['topic'];
    if (topic == null) return null;
    if (topic is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid topic.');
    }
    return _topic(topic);
  }

  @override
  Future<ForumTopic> createTopic(ForumTopic topic) async {
    final response = await _apiClient.request(
      'POST',
      'forum/topics',
      body: {'title': topic.title, 'movieId': topic.movieId},
    );
    final result = response['topic'];
    if (result is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid topic.');
    }
    return _topic(result);
  }

  @override
  Future<List<ForumMessage>> getMessagesForTopic(String topicId) async {
    final response = await _apiClient.request(
      'GET',
      'forum/topics/${Uri.encodeComponent(topicId)}/messages',
    );
    return _list(response, 'messages').map(_message).toList(growable: false);
  }

  @override
  Future<bool> postMessage(
    ForumMessage message, {
    required int userMessageCountLastMinute,
  }) async {
    try {
      await _apiClient.request(
        'POST',
        'forum/topics/${Uri.encodeComponent(message.topicId)}/messages',
        body: {'content': message.content},
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 429) return false;
      rethrow;
    }
  }

  @override
  Future<void> likeMessage(String messageId) async {
    await _apiClient.request(
      'POST',
      'forum/messages/${Uri.encodeComponent(messageId)}/likes',
      body: const {},
    );
  }

  @override
  Future<void> reportMessage(
    String targetId,
    String excerpt,
    String reason,
    String reporterId,
  ) async {
    await _report('message', targetId, reason);
  }

  @override
  Future<void> reportTopic(String targetId, String reason) =>
      _report('topic', targetId, reason);

  Future<void> _report(String type, String id, String reason) async {
    await _apiClient.request(
      'POST',
      'forum/reports',
      body: {'targetType': type, 'targetId': id, 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> _moderationData() =>
      _apiClient.request('GET', 'forum/moderation/reports');

  @override
  Future<List<ForumReport>> getModerationReports() async {
    final response = await _moderationData();
    return _list(
      response,
      'reports',
    ).map(_reportFromJson).toList(growable: false);
  }

  @override
  Future<List<ForumRestriction>> getActiveRestrictions() async {
    final response = await _moderationData();
    return _list(
      response,
      'restrictions',
    ).map(_restriction).toList(growable: false);
  }

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    final action = switch (status) {
      'dismissed' || 'processed' => 'dismiss',
      'removed' || 'hidden' => 'remove',
      'restricted' => 'restrict',
      _ => throw ArgumentError.value(status, 'status', 'Unsupported action'),
    };
    await _apiClient.request(
      'POST',
      'forum/moderation/reports/${Uri.encodeComponent(reportId)}/action',
      body: {'action': action},
    );
  }

  @override
  Future<void> liftRestriction(String restrictionId) async {
    await _apiClient.request(
      'POST',
      'forum/moderation/restrictions/${Uri.encodeComponent(restrictionId)}/lift',
      body: const {},
    );
  }
}

final backendForumServiceProvider = Provider<ForumService>(
  (ref) => BackendForumService(ref.watch(apiClientProvider)),
);
