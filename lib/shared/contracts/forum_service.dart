class ForumMessage {
  final String id;
  final String topicId;
  final String userId;
  final String userNickname;
  final bool isModerator;
  final String content;
  final int likeCount;
  final DateTime timestamp;
  final bool isDeleted;

  const ForumMessage({
    required this.id,
    required this.topicId,
    required this.userId,
    required this.userNickname,
    this.isModerator = false,
    required this.content,
    this.likeCount = 0,
    required this.timestamp,
    this.isDeleted = false,
  });
}

class ForumTopic {
  final String id;
  final String title;
  final String? movieId;
  final String authorId;
  final String authorNickname;
  final int replyCount;
  final DateTime timestamp;
  final bool isHidden;

  const ForumTopic({
    required this.id,
    required this.title,
    this.movieId,
    required this.authorId,
    required this.authorNickname,
    this.replyCount = 0,
    required this.timestamp,
    this.isHidden = false,
  });
}

class ForumReport {
  final String id;
  final String targetId; // messageId or topicId
  final String targetExcerpt;
  final String reason;
  final String reporterId;
  final int reportCount;
  final String status; // 'pending', 'hidden', 'processed'
  final DateTime timestamp;
  final String targetType;
  final String targetAuthorId;
  final String targetAuthorNickname;
  final String reporterNicknames;

  const ForumReport({
    required this.id,
    required this.targetId,
    required this.targetExcerpt,
    required this.reason,
    required this.reporterId,
    this.reportCount = 1,
    this.status = 'pending',
    required this.timestamp,
    this.targetType = 'message',
    this.targetAuthorId = '',
    this.targetAuthorNickname = '',
    this.reporterNicknames = '',
  });
}

class ForumRestriction {
  const ForumRestriction({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final String userId;
  final String userNickname;
  final String reason;
  final DateTime timestamp;
}

abstract class ForumService {
  Future<List<ForumTopic>> getTopics({String? movieId});
  Future<ForumTopic?> getTopicById(String id);
  Future<ForumTopic> createTopic(ForumTopic topic);
  Future<List<ForumMessage>> getMessagesForTopic(String topicId);
  Future<bool> postMessage(
    ForumMessage message, {
    required int userMessageCountLastMinute,
  });
  Future<void> likeMessage(String messageId);
  Future<void> reportMessage(
    String targetId,
    String excerpt,
    String reason,
    String reporterId,
  );
  Future<void> reportTopic(String targetId, String reason);
  Future<List<ForumReport>> getModerationReports();
  Future<void> updateReportStatus(String reportId, String status);
  Future<List<ForumRestriction>> getActiveRestrictions();
  Future<void> liftRestriction(String restrictionId);
}
