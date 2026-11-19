import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movietracker/features/journal/presentation/log_viewing_page.dart';
import 'package:movietracker/shared/contracts/auth_service.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';

void main() {
  testWidgets('preselects the movie opened from its detail page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            const UserProfile(
              id: 'user_1',
              email: 'cinephile@example.com',
              nickname: 'Cinephile',
              country: 'US',
            ),
          ),
          movieRepositoryProvider.overrideWith((ref) => FakeMovieRepository()),
          reviewServiceProvider.overrideWith((ref) => FakeReviewService()),
        ],
        child: const MaterialApp(home: LogViewingPage(movieId: 'm1')),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Movie Title 1: The Epic Saga',
    );
    await tester.scrollUntilVisible(
      find.text('Save to journal'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Movie Title 1: The Epic Saga'), findsOneWidget);
    expect(find.text('Save to journal'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
