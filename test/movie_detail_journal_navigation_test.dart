import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movietracker/features/catalog/presentation/movie_detail_page.dart';
import 'package:movietracker/features/journal/presentation/log_viewing_page.dart';
import 'package:movietracker/features/journal/presentation/review_form_page.dart';
import 'package:movietracker/main.dart';
import 'package:movietracker/shared/contracts/auth_service.dart';
import 'package:movietracker/shared/contracts/fake_data_source.dart';
import 'package:movietracker/core/router/app_router.dart';

void main() {
  testWidgets('opens journal forms from a movie and returns to the movie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_SignedInAuthService()),
        movieRepositoryProvider.overrideWith((ref) => FakeMovieRepository()),
        reviewServiceProvider.overrideWith((ref) => FakeReviewService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MovieTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/movie/m1');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Log a viewing'));
    await tester.pumpAndSettle();
    expect(find.byType(LogViewingPage), findsOneWidget);

    container.read(appRouterProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MovieDetailPage), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Write a review'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewFormPage), findsOneWidget);
  });
}

class _SignedInAuthService implements AuthService {
  static const _user = UserProfile(
    id: 'test_user',
    email: 'test@example.com',
    nickname: 'Test user',
    country: 'US',
  );

  @override
  Future<UserProfile?> getCurrentUser() async => _user;

  @override
  Future<UserProfile> signIn(
    String email,
    String password, {
    bool rememberMe = true,
  }) async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String nickname, {
    required String country,
    required List<String> favoriteGenres,
  }) async => _user;

  @override
  Future<UserProfile> updateProfile({
    required String nickname,
    required String country,
    required List<String> favoriteGenres,
  }) async => _user;
}
