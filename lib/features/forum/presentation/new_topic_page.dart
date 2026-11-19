import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/forum_service.dart';
import 'forum_providers.dart';

class NewTopicPage extends ConsumerStatefulWidget {
  const NewTopicPage({super.key});

  @override
  ConsumerState<NewTopicPage> createState() => _NewTopicPageState();
}

class _NewTopicPageState extends ConsumerState<NewTopicPage> {
  final _titleController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  Future<void> _createTopic() async {
    final title = _titleController.text.trim();
    if (title.length < 5 || title.length > 120) {
      setState(() => _error = 'Choose a title between 5 and 120 characters.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final topic = await ref
          .read(forumServiceProvider)
          .createTopic(
            ForumTopic(
              id: '',
              title: title,
              authorId: user.id,
              authorNickname: user.nickname,
              timestamp: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ref.invalidate(forumTopicsProvider);
      context.go('/forum/topic/${topic.id}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Start a discussion')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Share a perspective, ask a question, or start a conversation about cinema.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Discussion title',
              hintText: 'What makes a movie unforgettable?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _createTopic,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish discussion'),
          ),
        ],
      ),
    );
  }
}
