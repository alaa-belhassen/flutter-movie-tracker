import 'package:flutter_test/flutter_test.dart';
import 'package:movietracker/shared/contracts/review_service.dart';
import 'package:movietracker/shared/contracts/forum_service.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';

void main() {
  group('Business Logic Tests', () {
    test('Unique nickname check', () async {
      final directory = FakeUserDirectory();
      final isUnique = await directory.isNicknameUnique('CineMaster');
      expect(isUnique, false);

      final isNewUnique = await directory.isNicknameUnique('BrandNewUser123');
      expect(isNewUnique, true);
    });

    test('Journal stats do not invent watched films', () async {
      final reviewService = FakeReviewService();
      final stats = await reviewService.getUserStats('user_1');
      expect(stats['moviesWatched'], 0);
      expect(stats['viewingCount'], 0);
      expect(stats['avgRating'], 0);
    });

    test('One review per user per movie stubs', () async {
      final reviewService = FakeReviewService();
      final review1 = Review(
        id: 'r_test_1',
        movieId: 'm2',
        userId: 'user_1',
        userNickname: 'CineMaster',
        rating: 5.0,
        content: 'Great film',
        containsSpoiler: false,
        isRewatch: false,
        timestamp: DateTime.now(),
      );
      await reviewService.saveReview(review1);

      final fetched = await reviewService.getUserReviewForMovie('user_1', 'm2');
      expect(fetched, isNotNull);
      expect(fetched?.rating, 5.0);
    });

    test('Anti-spam 5 messages per minute check', () async {
      final forumService = FakeForumService();
      final msg = ForumMessage(
        id: 'fm_spam',
        topicId: 'ft1',
        userId: 'user_1',
        userNickname: 'CineMaster',
        content: 'Hello spam',
        timestamp: DateTime.now(),
      );

      final postedAllowed = await forumService.postMessage(
        msg,
        userMessageCountLastMinute: 4,
      );
      expect(postedAllowed, true);

      final postedBlocked = await forumService.postMessage(
        msg,
        userMessageCountLastMinute: 5,
      );
      expect(postedBlocked, false);
    });

    test('Watchlist vs watched exclusion', () async {
      final watchlistService = FakeWatchlistService();
      await watchlistService.toggleWatchlist('user_1', 'm10');
      final watchlist = await watchlistService.getWatchlist('user_1');
      expect(watchlist.contains('m10'), true);

      final pick = await watchlistService.tonightPicker(
        userId: 'user_1',
        maxDurationMinutes: 180,
      );
      expect(watchlist.contains(pick?.movieId), false);
    });
  });
}
