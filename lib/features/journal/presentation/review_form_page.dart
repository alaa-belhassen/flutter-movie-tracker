import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/review_service.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../core/widgets/rating_bar.dart';
import 'journal_home_page.dart';
import '../../users/presentation/user_stats_provider.dart';

class ReviewFormPage extends ConsumerStatefulWidget {
  final String movieId;
  const ReviewFormPage({super.key, required this.movieId});

  @override
  ConsumerState<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends ConsumerState<ReviewFormPage> {
  double _rating = 4.0;
  final _contentController = TextEditingController();
  bool _containsSpoiler = false;
  bool _isRewatch = false;
  bool _isSaving = false;
  String? _error;

  Future<void> _publishReview() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      setState(
        () => _error = 'Write a few words before publishing your review.',
      );
      return;
    }
    final reviewService = ref.read(reviewServiceProvider);

    final review = Review(
      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
      movieId: widget.movieId,
      userId: user.id,
      userNickname: user.nickname,
      rating: _rating,
      content: _contentController.text,
      containsSpoiler: _containsSpoiler,
      isRewatch: _isRewatch,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await reviewService.saveReview(review);
      if (!mounted) return;
      ref.invalidate(journalDataProvider(user.id));
      ref.invalidate(userStatsProvider(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review published successfully!')),
      );
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Write Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rate this movie', style: textTheme.headlineMedium),
            const SizedBox(height: 12),
            Center(
              child: RatingBar(
                rating: _rating,
                onRatingChanged: (val) => setState(() => _rating = val),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Your review'),
              maxLines: 5,
              maxLength: 3000,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Contains a spoiler'),
              value: _containsSpoiler,
              onChanged: (val) => setState(() => _containsSpoiler = val),
            ),
            SwitchListTile(
              title: const Text('This is a rewatch'),
              value: _isRewatch,
              onChanged: (val) => setState(() => _isRewatch = val),
            ),
            const SizedBox(height: 32),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _isSaving ? null : _publishReview,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish review'),
            ),
          ],
        ),
      ),
    );
  }
}
