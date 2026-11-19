import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/forum_service.dart';
import '../../../core/widgets/role_badge.dart';
import 'forum_providers.dart';

class TopicPage extends ConsumerStatefulWidget {
  const TopicPage({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends ConsumerState<TopicPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(forumMessagesProvider(widget.topicId));
    });
  }

  Future<void> _postMessage() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final sent = await ref
          .read(forumServiceProvider)
          .postMessage(
            ForumMessage(
              id: '',
              topicId: widget.topicId,
              userId: user.id,
              userNickname: user.nickname,
              isModerator: user.isModerator,
              content: content,
              timestamp: DateTime.now(),
            ),
            userMessageCountLastMinute: 0,
          );
      if (!mounted) return;
      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Limit reached: 5 messages per minute.'),
          ),
        );
        return;
      }
      _messageController.clear();
      ref.invalidate(forumMessagesProvider(widget.topicId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _reportMessage(ForumMessage message) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report message'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Tell moderators why this message should be reviewed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Send report'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    if (reason.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason (at least 5 characters).'),
        ),
      );
      return;
    }
    try {
      await ref
          .read(forumServiceProvider)
          .reportMessage(message.id, message.content, reason, user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to the moderators.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _likeMessage(ForumMessage message) async {
    try {
      await ref.read(forumServiceProvider).likeMessage(message.id);
      ref.invalidate(forumMessagesProvider(widget.topicId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = ref.watch(forumTopicProvider(widget.topicId));
    final messages = ref.watch(forumMessagesProvider(widget.topicId));
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    ref.listen(forumMessagesProvider(widget.topicId), (previous, next) {
      if (!next.hasValue) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: topic.when(
          data: (value) => Text(
            value?.title ?? 'Discussion',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          error: (error, stackTrace) => const Text('Discussion'),
          loading: () => const Text('Discussion'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: () =>
                ref.invalidate(forumMessagesProvider(widget.topicId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          topic.when(
            data: (value) => value == null
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    color: colorScheme.surfaceContainerHighest,
                    child: Text(
                      'Started by ${value.authorNickname} · Live discussion',
                      style: textTheme.bodySmall,
                    ),
                  ),
            error: (error, stackTrace) => const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
          ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error.toString(), textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          forumMessagesProvider(widget.topicId),
                        ),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 80),
                      Icon(Icons.chat_bubble_outline, size: 44),
                      SizedBox(height: 12),
                      Center(
                        child: Text('Be the first to share a perspective.'),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(forumMessagesProvider(widget.topicId));
                    await ref.read(
                      forumMessagesProvider(widget.topicId).future,
                    );
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final message = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message.userNickname,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (message.isModerator) const RoleBadge(),
                                  if (!message.isDeleted)
                                    PopupMenuButton<String>(
                                      tooltip: 'Message actions',
                                      onSelected: (action) {
                                        if (action == 'report') {
                                          _reportMessage(message);
                                        } else {
                                          _likeMessage(message);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'like',
                                          child: Text('Like'),
                                        ),
                                        PopupMenuItem(
                                          value: 'report',
                                          child: Text('Report'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message.content,
                                style: message.isDeleted
                                    ? textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      )
                                    : textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite_border,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${message.likeCount}'),
                                  const Spacer(),
                                  Text(
                                    MaterialLocalizations.of(context)
                                        .formatShortDate(message.timestamp),
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: user != null && !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      onSubmitted: (_) => _postMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Share your perspective…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isSending ? null : _postMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
