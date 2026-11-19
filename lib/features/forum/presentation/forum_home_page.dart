import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import 'forum_providers.dart';

class ForumHomePage extends ConsumerWidget {
  const ForumHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final topics = ref.watch(forumTopicsProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          if (user?.isModerator == true)
            IconButton(
              tooltip: 'Moderation',
              onPressed: () => context.push('/forum/moderation'),
              icon: const Icon(Icons.shield_outlined),
            ),
          IconButton(
            tooltip: 'Refresh topics',
            onPressed: () => ref.invalidate(forumTopicsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/forum/new');
          ref.invalidate(forumTopicsProvider);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New discussion'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(forumTopicsProvider);
          await ref.read(forumTopicsProvider.future);
        },
        child: topics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ListView(
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              Center(
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(forumTopicsProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.forum_outlined, size: 52, color: colors.primary),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Start the conversation',
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Create a topic and share your movie perspective.',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final topic = items[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/forum/topic/${topic.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.forum_outlined, color: colors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  topic.title,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'by ${topic.authorNickname} · ${topic.replyCount} replies',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
