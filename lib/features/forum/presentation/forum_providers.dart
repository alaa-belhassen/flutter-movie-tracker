import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/forum_service.dart';

final forumTopicsProvider = FutureProvider.autoDispose<List<ForumTopic>>((ref) {
  return ref.watch(forumServiceProvider).getTopics();
});

final forumTopicProvider = FutureProvider.autoDispose
    .family<ForumTopic?, String>((ref, topicId) {
      return ref.watch(forumServiceProvider).getTopicById(topicId);
    });

final forumMessagesProvider = FutureProvider.autoDispose
    .family<List<ForumMessage>, String>((ref, topicId) {
      return ref.watch(forumServiceProvider).getMessagesForTopic(topicId);
    });

class ModerationData {
  const ModerationData({required this.reports, required this.restrictions});

  final List<ForumReport> reports;
  final List<ForumRestriction> restrictions;
}

final moderationDataProvider = FutureProvider.autoDispose<ModerationData>((
  ref,
) async {
  final service = ref.watch(forumServiceProvider);
  final result = await Future.wait<dynamic>([
    service.getModerationReports(),
    service.getActiveRestrictions(),
  ]);
  return ModerationData(
    reports: result[0] as List<ForumReport>,
    restrictions: result[1] as List<ForumRestriction>,
  );
});
