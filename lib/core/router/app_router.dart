import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/contracts/auth_service.dart';
import '../widgets/app_nav_bar.dart';

import '../../features/users/presentation/login_page.dart';
import '../../features/users/presentation/signup_page.dart';
import '../../features/users/presentation/signup_profile_page.dart';
import '../../features/users/presentation/forgot_password_page.dart';
import '../../features/users/presentation/profile_home_page.dart';
import '../../features/users/presentation/profile_page.dart';
import '../../features/users/presentation/settings_page.dart';
import '../../features/users/presentation/stats_dashboard_page.dart';
import '../../features/users/presentation/year_recap_page.dart';

import '../../features/catalog/presentation/catalog_home_page.dart';
import '../../features/catalog/presentation/search_page.dart';
import '../../features/catalog/presentation/explore_movies_page.dart';
import '../../features/catalog/presentation/genre_page.dart';
import '../../features/catalog/presentation/search_history_page.dart';
import '../../features/catalog/presentation/where_to_watch_page.dart';
import '../../features/catalog/presentation/movie_detail_page.dart';

import '../../features/journal/presentation/journal_home_page.dart';
import '../../features/journal/presentation/log_viewing_page.dart';
import '../../features/journal/presentation/review_form_page.dart';

import '../../features/lists/presentation/lists_home_page.dart';
import '../../features/lists/presentation/shared_list_page.dart';
import '../../features/lists/presentation/tonight_picker_page.dart';

import '../../features/people/presentation/people_home_page.dart';
import '../../features/people/presentation/actor_page.dart';
import '../../features/people/presentation/recommendations_page.dart';

import '../../features/forum/presentation/forum_home_page.dart';
import '../../features/forum/presentation/new_topic_page.dart';
import '../../features/forum/presentation/topic_page.dart';
import '../../features/forum/presentation/moderation_queue_page.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

SignupCredentials? _signupCredentialsFromExtra(Object? extra) {
  if (extra is! Map) return null;
  final email = extra['email'];
  final password = extra['password'];
  if (email is! String || password is! String) return null;
  return SignupCredentials(email: email, password: password);
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth-loading',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loggedInUser = authState.valueOrNull;
      final location = state.matchedLocation;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/signup/profile' ||
          state.matchedLocation == '/forgot-password';

      final isPublic =
          location.startsWith('/discover') || location.startsWith('/movie');

      if (authState.isLoading) {
        if (location == '/auth-loading' || isLoggingIn || isPublic) {
          return null;
        }
        return '/auth-loading';
      }

      if (location == '/auth-loading') {
        return loggedInUser == null ? '/login' : '/discover';
      }

      if (location == '/signup/profile' &&
          _signupCredentialsFromExtra(state.extra) == null) {
        return '/signup';
      }

      if (loggedInUser != null && isLoggingIn) {
        return '/discover';
      }

      if (loggedInUser == null && !isLoggingIn && !isPublic) {
        return '/login';
      }

      if (location == '/forum/moderation' &&
          (loggedInUser == null || !loggedInUser.isModerator)) {
        return '/forum';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth-loading',
        builder: (context, state) => const AuthLoadingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/signup/profile',
        builder: (context, state) {
          final credentials = _signupCredentialsFromExtra(state.extra);
          return SignupProfilePage(credentials: credentials);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const CatalogHomePage(),
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchPage(),
                  ),
                  GoRoute(
                    path: 'all',
                    builder: (context, state) => const ExploreMoviesPage(),
                  ),
                  GoRoute(
                    path: 'genre/:id',
                    builder: (context, state) =>
                        GenrePage(genreId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const SearchHistoryPage(),
                  ),
                  GoRoute(
                    path: 'where',
                    builder: (context, state) => const WhereToWatchPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journal',
                builder: (context, state) => const JournalHomePage(),
                routes: [
                  GoRoute(
                    path: 'log',
                    builder: (context, state) => const LogViewingPage(),
                  ),
                  GoRoute(
                    path: 'log/:movieId',
                    builder: (context, state) => LogViewingPage(
                      movieId: state.pathParameters['movieId'],
                    ),
                  ),
                  GoRoute(
                    path: 'review/:movieId',
                    builder: (context, state) => ReviewFormPage(
                      movieId: state.pathParameters['movieId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lists',
                builder: (context, state) => const ListsHomePage(),
                routes: [
                  GoRoute(
                    path: 'tonight',
                    builder: (context, state) => const TonightPickerPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        SharedListPage(listId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/forum',
                builder: (context, state) => const ForumHomePage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const NewTopicPage(),
                  ),
                  GoRoute(
                    path: 'topic/:id',
                    builder: (context, state) =>
                        TopicPage(topicId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'moderation',
                    builder: (context, state) => const ModerationQueuePage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileHomePage(),
                routes: [
                  GoRoute(
                    path: 'me',
                    builder: (context, state) => const ProfilePage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsPage(),
                  ),
                  GoRoute(
                    path: 'stats',
                    builder: (context, state) => const StatsDashboardPage(),
                  ),
                  GoRoute(
                    path: 'recap/:year',
                    builder: (context, state) =>
                        YearRecapPage(year: state.pathParameters['year']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (context, state) =>
            MovieDetailPage(movieId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/people',
        builder: (context, state) => const PeopleHomePage(),
        routes: [
          GoRoute(
            path: 'actor/:id',
            builder: (context, state) =>
                ActorPage(actorId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'for-you',
            builder: (context, state) => const RecommendationsPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
