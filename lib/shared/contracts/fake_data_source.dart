import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'user_directory.dart';
import 'settings_service.dart';
import 'movie_repository.dart';
import 'review_service.dart';
import 'watchlist_service.dart';
import 'recommendation_service.dart';
import 'actor_repository.dart';
import 'forum_service.dart';
import 'tmdb_movie_repository.dart';
import 'backend_watchlist_service.dart';
import 'backend_review_service.dart';
import 'backend_forum_service.dart';
import 'backend_recommendation_service.dart';
import 'tmdb_actor_repository.dart';
import 'api_client.dart';

class FakeDataSource {
  static final List<AppUser> users = [
    const AppUser(
      id: 'user_1',
      email: 'cinephile@movietracker.com',
      nickname: 'CineMaster',
      country: 'US',
      isModerator: true,
    ),
    const AppUser(
      id: 'user_2',
      email: 'alice@movietracker.com',
      nickname: 'AliceMovies',
      country: 'FR',
      isModerator: false,
    ),
    const AppUser(
      id: 'user_3',
      email: 'bob@movietracker.com',
      nickname: 'BobCritique',
      country: 'US',
      isModerator: false,
    ),
    const AppUser(
      id: 'user_4',
      email: 'claire@movietracker.com',
      nickname: 'ClaireCinema',
      country: 'CA',
      isModerator: false,
    ),
    const AppUser(
      id: 'user_5',
      email: 'david@movietracker.com',
      nickname: 'DavidFilm',
      country: 'UK',
      isModerator: false,
    ),
  ];

  static final List<Actor> actors = [
    const Actor(
      id: 'actor_1',
      name: 'Liam Vance',
      role: 'Lead Actor',
      birthplace: 'London, UK',
      bio: 'Award-winning actor known for intense dramatic roles in sci-fi and thriller masterpieces.',
      movieIds: ['m1', 'm2', 'm5'],
      isFollowing: true,
    ),
    const Actor(
      id: 'actor_2',
      name: 'Elena Rostova',
      role: 'Lead Actress',
      birthplace: 'Moscow, Russia',
      bio: 'Internationally acclaimed star of European cinema and Hollywood blockbusters.',
      movieIds: ['m1', 'm3', 'm8'],
      isFollowing: true,
    ),
    const Actor(
      id: 'actor_3',
      name: 'Marcus Sterling',
      role: 'Supporting Actor',
      birthplace: 'New York, USA',
      bio: 'Veteran character actor with over 50 film credits.',
      movieIds: ['m2', 'm4', 'm6'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_4',
      name: 'Sophie Laurent',
      role: 'Lead Actress',
      birthplace: 'Paris, France',
      bio: 'Iconic French actress celebrated for her emotional depth and elegance.',
      movieIds: ['m3', 'm7', 'm9'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_5',
      name: 'Kenji Sato',
      role: 'Director & Actor',
      birthplace: 'Tokyo, Japan',
      bio: 'Visionary auteur redefining modern action and animation.',
      movieIds: ['m5', 'm10', 'm11'],
      isFollowing: true,
    ),
    const Actor(
      id: 'actor_6',
      name: 'Aria Stark',
      role: 'Actress',
      birthplace: 'Sydney, Australia',
      bio: 'Rising star in sci-fi adventure epics.',
      movieIds: ['m6', 'm12', 'm13'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_7',
      name: 'Gabriel Byrne Jr.',
      role: 'Actor',
      birthplace: 'Dublin, Ireland',
      bio: 'Intense dramatic performer.',
      movieIds: ['m2', 'm14', 'm15'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_8',
      name: 'Zoe Saldana-Smith',
      role: 'Actress',
      birthplace: 'Miami, USA',
      bio: 'Action royalty and blockbuster queen.',
      movieIds: ['m1', 'm16', 'm17'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_9',
      name: 'Omar Sy-Bello',
      role: 'Actor',
      birthplace: 'Dakar, Senegal',
      bio: 'Charismatic leading man of comedy and drama.',
      movieIds: ['m3', 'm18', 'm19'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_10',
      name: 'Penelope Cruz-Mendez',
      role: 'Actress',
      birthplace: 'Madrid, Spain',
      bio: 'Legendary Spanish dramatic powerhouse.',
      movieIds: ['m4', 'm20', 'm21'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_11',
      name: 'Daniel Kaluuya-Jones',
      role: 'Actor',
      birthplace: 'London, UK',
      bio: 'Groundbreaking psychological thriller icon.',
      movieIds: ['m5', 'm22', 'm23'],
      isFollowing: false,
    ),
    const Actor(
      id: 'actor_12',
      name: 'Florence Pugh-Davies',
      role: 'Actress',
      birthplace: 'Oxford, UK',
      bio: 'Fearless character chameleon.',
      movieIds: ['m6', 'm23', 'm24'],
      isFollowing: true,
    ),
  ];

  static final List<Movie> movies = List.generate(24, (index) {
    final id = 'm${index + 1}';
    final genres = [
      'Action',
      'Sci-Fi',
      'Drama',
      'Thriller',
      'Comedy',
      'Romance',
      'Animation',
      'Horror',
    ];
    final genre = genres[index % genres.length];
    final year = 2020 + (index % 6);
    final rating = 3.5 + ((index % 15) * 0.1);
    return Movie(
      id: id,
      title: 'Movie Title ${index + 1}: The Epic Saga',
      year: year,
      genre: genre,
      duration: '${1 + (index % 2)}h ${30 + (index * 5) % 30}m',
      rating: rating > 5.0 ? 5.0 : rating,
      synopsis:
          'An unforgettable cinematic journey filled with suspense, passion, and breathtaking visuals in Movie Title ${index + 1}. [Spoiler: The hero saves the galaxy at the end].',
      castIds: ['actor_${(index % 12) + 1}', 'actor_${((index + 1) % 12) + 1}'],
      streamingProviders: ['Netflix', 'Apple TV+', 'Disney+', 'Canal+'],
      isTrending: index < 8,
      isFeatured: index < 4,
    );
  });

  static final List<Review> reviews = [
    Review(
      id: 'r1',
      movieId: 'm1',
      userId: 'user_1',
      userNickname: 'CineMaster',
      rating: 5.0,
      content:
          'Absolute masterpiece! The direction and score are breathtaking.',
      containsSpoiler: false,
      isRewatch: false,
      helpfulCount: 12,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Review(
      id: 'r2',
      movieId: 'm1',
      userId: 'user_2',
      userNickname: 'AliceMovies',
      rating: 4.5,
      content: 'Brilliant performances, though the third act was slightly rushed. [Spoiler: The twist ending changed everything.]',
      containsSpoiler: true,
      isRewatch: false,
      helpfulCount: 8,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static List<String> watchlist = [];
  static List<String> favorites = [];

  static final List<CustomList> customLists = [];

  static final List<SearchHistoryItem> searchHistory = [];

  static final List<ForumTopic> topics = [
    ForumTopic(
      id: 'ft1',
      title: 'What was your favorite scene in Movie 1?',
      movieId: 'm1',
      authorId: 'user_1',
      authorNickname: 'CineMaster',
      replyCount: 3,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ForumTopic(
      id: 'ft2',
      title: 'General discussion on 2025 cinema releases',
      movieId: null,
      authorId: 'user_2',
      authorNickname: 'AliceMovies',
      replyCount: 5,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<ForumMessage> messages = [
    ForumMessage(
      id: 'fm1',
      topicId: 'ft1',
      userId: 'user_1',
      userNickname: 'CineMaster',
      isModerator: true,
      content: 'The opening sequence is unmatched in recent cinema history!',
      likeCount: 5,
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ForumMessage(
      id: 'fm2',
      topicId: 'ft1',
      userId: 'user_3',
      userNickname: 'BobCritique',
      isModerator: false,
      content: 'Agree 100%! The sound design was out of this world.',
      likeCount: 2,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  static final List<ForumReport> reports = [
    ForumReport(
      id: 'fr1',
      targetId: 'fm2',
      targetExcerpt: 'Spamming irrelevant links',
      reason: 'Spam',
      reporterId: 'user_2',
      reportCount: 2,
      status: 'pending',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];
}

class FakeUserDirectory implements UserDirectory {
  @override
  Future<List<AppUser>> getAllUsers() async => FakeDataSource.users;

  @override
  Future<AppUser?> getUserById(String id) async {
    try {
      return FakeDataSource.users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isNicknameUnique(String nickname) async {
    return !FakeDataSource.users.any(
      (u) => u.nickname.toLowerCase() == nickname.toLowerCase(),
    );
  }

  @override
  Future<void> updateUser(AppUser user) async {
    final idx = FakeDataSource.users.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      FakeDataSource.users[idx] = user;
    }
  }
}

class FakeSettingsService implements SettingsService {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> getSettings() async => _settings;

  @override
  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class FakeMovieRepository implements MovieRepository {
  @override
  Future<List<Movie>> getMovies({int? maxRuntimeMinutes}) async {
    final movies = FakeDataSource.movies;
    if (maxRuntimeMinutes == null) return movies;
    return movies.where((movie) {
      final match = RegExp(r'^(\d+)h\s+(\d+)m$').firstMatch(movie.duration);
      if (match == null) return false;
      final minutes = int.parse(match[1]!) * 60 + int.parse(match[2]!);
      return minutes <= maxRuntimeMinutes;
    }).toList();
  }

  @override
  Future<List<Movie>> discoverMovies({
    String? genre,
    String? actor,
    String? actorId,
    double? minRating,
    int? year,
  }) async {
    return FakeDataSource.movies.where((movie) {
      final matchesGenre =
          genre == null ||
          genre.isEmpty ||
          movie.genre.toLowerCase().contains(genre.toLowerCase());
      final matchesActor =
          actor == null ||
          actor.isEmpty ||
          movie.castIds.any(
            (castId) => castId.toLowerCase().contains(actor.toLowerCase()),
          );
      final matchesRating = minRating == null || movie.rating >= minRating;
      final matchesYear = year == null || movie.year == year;
      return matchesGenre && matchesActor && matchesRating && matchesYear;
    }).toList();
  }

  @override
  Future<List<MovieActorSuggestion>> searchActors(String query) async =>
      FakeDataSource.actors
          .where(
            (actor) => actor.name.toLowerCase().contains(query.toLowerCase()),
          )
          .map(
            (actor) => MovieActorSuggestion(
              id: actor.id,
              name: actor.name,
              knownForDepartment: actor.role,
            ),
          )
          .toList();

  @override
  Future<List<MovieActorSuggestion>> getPopularActors() async => FakeDataSource
      .actors
      .map(
        (actor) => MovieActorSuggestion(
          id: actor.id,
          name: actor.name,
          knownForDepartment: actor.role,
        ),
      )
      .toList(growable: false);

  @override
  Future<MoviePerson?> getPersonById(String id) async {
    try {
      final actor = FakeDataSource.actors.firstWhere((actor) => actor.id == id);
      return MoviePerson(
        id: actor.id,
        name: actor.name,
        knownForDepartment: actor.role,
        biography: actor.bio,
        placeOfBirth: actor.birthplace,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Movie>> getActorMovies(String actorId) async {
    final actor = FakeDataSource.actors.where((actor) => actor.id == actorId);
    if (actor.isEmpty) return const [];
    return FakeDataSource.movies
        .where((movie) => actor.first.movieIds.contains(movie.id))
        .toList(growable: false);
  }

  @override
  Future<List<CastMember>> getMovieCast(String movieId) async {
    final movie = await getMovieById(movieId);
    if (movie == null) return const [];
    return movie.castIds
        .map((id) {
          final actors = FakeDataSource.actors.where((actor) => actor.id == id);
          final actor = actors.isEmpty ? null : actors.first;
          return CastMember(
            id: id,
            name: actor?.name ?? 'Unknown actor',
            character: actor?.role ?? '',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Movie?> getMovieById(String id) async {
    try {
      return FakeDataSource.movies.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Movie>> searchMovies(
    String query, {
    String? genre,
    int? year,
    double? minRating,
  }) async {
    return FakeDataSource.movies.where((m) {
      final matchesQuery =
          m.title.toLowerCase().contains(query.toLowerCase()) ||
          m.genre.toLowerCase().contains(query.toLowerCase());
      final matchesGenre =
          genre == null ||
          genre.isEmpty ||
          m.genre.toLowerCase() == genre.toLowerCase();
      final matchesYear = year == null || m.year == year;
      final matchesRating = minRating == null || m.rating >= minRating;
      return matchesQuery && matchesGenre && matchesYear && matchesRating;
    }).toList();
  }

  @override
  Future<List<Movie>> getTrendingMovies() async =>
      FakeDataSource.movies.where((m) => m.isTrending).toList();

  @override
  Future<List<Movie>> getFeaturedMovies() async =>
      FakeDataSource.movies.where((m) => m.isFeatured).toList();

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) async => FakeDataSource
      .movies
      .where((m) => m.genre.toLowerCase() == genre.toLowerCase())
      .toList();

  @override
  Future<List<SearchHistoryItem>> getSearchHistory() async =>
      FakeDataSource.searchHistory;

  @override
  Future<void> addSearchHistory(String query) async {
    if (query.isNotEmpty) {
      FakeDataSource.searchHistory.insert(
        0,
        SearchHistoryItem(
          id: 'sh_${DateTime.now().millisecondsSinceEpoch}',
          query: query,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> deleteSearchHistory(String id) async {
    FakeDataSource.searchHistory.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> clearSearchHistory() async {
    FakeDataSource.searchHistory.clear();
  }

  @override
  Future<List<String>> getStreamingProviders(String country) async {
    return ['Netflix', 'Apple TV+', 'Disney+', 'Canal+', 'Amazon Prime'];
  }
}

class FakeReviewService implements ReviewService {
  static final List<ViewingEntry> _viewings = [];

  @override
  Future<List<Review>> getReviewsForMovie(String movieId) async {
    return FakeDataSource.reviews.where((r) => r.movieId == movieId).toList();
  }

  @override
  Future<List<Review>> getUserReviews(String userId) async {
    return FakeDataSource.reviews.where((r) => r.userId == userId).toList();
  }

  @override
  Future<Review?> getUserReviewForMovie(String userId, String movieId) async {
    try {
      return FakeDataSource.reviews.firstWhere(
        (r) => r.userId == userId && r.movieId == movieId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReview(Review review) async {
    final idx = FakeDataSource.reviews.indexWhere(
      (r) =>
          r.id == review.id ||
          (r.userId == review.userId && r.movieId == review.movieId),
    );
    if (idx != -1) {
      FakeDataSource.reviews[idx] = review;
    } else {
      FakeDataSource.reviews.add(review);
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    FakeDataSource.reviews.removeWhere((r) => r.id == reviewId);
  }

  @override
  Future<void> markHelpful(String reviewId) async {
    // helpful count increment logic
  }

  @override
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    final userReviews = FakeDataSource.reviews
        .where((r) => r.userId == userId)
        .toList();
    final userViewings = _viewings;
    final ratedEntries = userViewings
        .where((entry) => entry.rating != null)
        .toList(growable: false);
    return {
      'moviesWatched': userViewings
          .map((entry) => entry.movieId)
          .toSet()
          .length,
      'viewingCount': userViewings.length,
      'avgRating': ratedEntries.isNotEmpty
          ? ratedEntries.map((entry) => entry.rating!).reduce((a, b) => a + b) /
                ratedEntries.length
          : 0.0,
      'publishedReviews': userReviews.length,
    };
  }

  @override
  Future<List<ViewingEntry>> getViewingEntries(String userId) async =>
      List.unmodifiable(_viewings);

  @override
  Future<ViewingEntry> logViewing({
    required String movieId,
    required DateTime watchedAt,
    double? rating,
    required bool isRewatch,
    required String notes,
  }) async {
    final entry = ViewingEntry(
      id: 'viewing_${DateTime.now().microsecondsSinceEpoch}',
      movieId: movieId,
      watchedAt: watchedAt,
      rating: rating,
      isRewatch: isRewatch,
      notes: notes,
    );
    _viewings.insert(0, entry);
    return entry;
  }

  @override
  Future<void> deleteViewingEntry(String entryId) async {
    _viewings.removeWhere((entry) => entry.id == entryId);
  }
}

class FakeWatchlistService implements WatchlistService {
  @override
  Future<List<String>> getWatchlist(String userId) async =>
      FakeDataSource.watchlist;

  @override
  Future<List<String>> getFavorites(String userId) async =>
      FakeDataSource.favorites;

  @override
  Future<void> toggleWatchlist(String userId, String movieId) async {
    if (FakeDataSource.watchlist.contains(movieId)) {
      FakeDataSource.watchlist.remove(movieId);
    } else {
      FakeDataSource.watchlist.add(movieId);
    }
  }

  @override
  Future<void> toggleFavorite(String userId, String movieId) async {
    if (FakeDataSource.favorites.contains(movieId)) {
      FakeDataSource.favorites.remove(movieId);
    } else {
      FakeDataSource.favorites.add(movieId);
    }
  }

  @override
  Future<void> addFavorite(String userId, String movieId) async {
    if (!FakeDataSource.favorites.contains(movieId)) {
      FakeDataSource.favorites.add(movieId);
    }
  }

  @override
  Future<List<CustomList>> getCustomLists(String userId) async =>
      FakeDataSource.customLists;

  @override
  Future<void> saveCustomList(CustomList list) async {
    final idx = FakeDataSource.customLists.indexWhere((l) => l.id == list.id);
    if (idx != -1) {
      FakeDataSource.customLists[idx] = list;
    } else {
      FakeDataSource.customLists.add(list);
    }
  }

  @override
  Future<void> deleteCustomList(String listId) async {
    FakeDataSource.customLists.removeWhere((l) => l.id == listId);
  }

  @override
  Future<CustomList> getCustomList(String listId) async {
    return FakeDataSource.customLists.firstWhere((list) => list.id == listId);
  }

  @override
  Future<CustomList> inviteToList(String listId, String email) async {
    final list = await getCustomList(listId);
    final member = FakeDataSource.users.firstWhere(
      (user) => user.email.toLowerCase() == email.trim().toLowerCase(),
    );
    final updated = CustomList(
      id: list.id,
      title: list.title,
      userId: list.userId,
      movieIds: list.movieIds,
      isShared: true,
      memberIds: {...list.memberIds, member.id}.toList(),
    );
    await saveCustomList(updated);
    return updated;
  }

  @override
  Future<void> removeListMember(String listId, String memberId) async {
    final list = await getCustomList(listId);
    await saveCustomList(
      CustomList(
        id: list.id,
        title: list.title,
        userId: list.userId,
        movieIds: list.movieIds,
        isShared: list.isShared,
        memberIds: list.memberIds.where((id) => id != memberId).toList(),
      ),
    );
  }

  @override
  Future<CustomList> addMovieToList(String listId, String movieId) async {
    final list = await getCustomList(listId);
    final updated = CustomList(
      id: list.id,
      title: list.title,
      userId: list.userId,
      movieIds: {...list.movieIds, movieId}.toList(),
      isShared: list.isShared,
      memberIds: list.memberIds,
    );
    await saveCustomList(updated);
    return updated;
  }

  @override
  Future<void> removeMovieFromList(String listId, String movieId) async {
    final list = await getCustomList(listId);
    await saveCustomList(
      CustomList(
        id: list.id,
        title: list.title,
        userId: list.userId,
        movieIds: list.movieIds.where((id) => id != movieId).toList(),
        isShared: list.isShared,
        memberIds: list.memberIds,
      ),
    );
  }

  @override
  Future<void> leaveSharedList(String listId) async {}

  @override
  Future<MovieRecommendationResult?> tonightPicker({
    required String userId,
    required int maxDurationMinutes,
    String? genre,
  }) async {
    final unwrapped = FakeDataSource.movies
        .where((m) => !FakeDataSource.watchlist.contains(m.id))
        .toList();
    if (unwrapped.isEmpty) return null;
    final picked = unwrapped.first;
    return MovieRecommendationResult(movieId: picked.id, title: picked.title);
  }
}

class FakeRecommendationService implements RecommendationService {
  @override
  Future<List<RecommendedMovie>> getRecommendations(String userId) async {
    return FakeDataSource.movies
        .take(5)
        .map(
          (m) => RecommendedMovie(
            movie: m,
            matchScore: 92,
            reason: 'You rated 5 stars in Sci-Fi',
          ),
        )
        .toList();
  }

  @override
  Future<void> excludeRecommendation(String userId, String movieId) async {
    // exclusion logic
  }
}

class FakeActorRepository implements ActorRepository {
  @override
  Future<List<Actor>> getActors() async => FakeDataSource.actors;

  @override
  Future<List<Actor>> searchActors(String query) async => FakeDataSource.actors
      .where((actor) => actor.name.toLowerCase().contains(query.toLowerCase()))
      .toList(growable: false);

  @override
  Future<Actor?> getActorById(String id) async {
    try {
      return FakeDataSource.actors.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Actor>> getFollowedActors(String userId) async =>
      FakeDataSource.actors.where((a) => a.isFollowing).toList();

  @override
  Future<List<String>> getFollowedActorIds(String userId) async =>
      FakeDataSource.actors
          .where((actor) => actor.isFollowing)
          .map((actor) => actor.id)
          .toList(growable: false);

  @override
  Future<void> toggleFollowActor(String userId, String actorId) async {
    final index = FakeDataSource.actors.indexWhere(
      (actor) => actor.id == actorId,
    );
    if (index == -1) return;
    final actor = FakeDataSource.actors[index];
    FakeDataSource.actors[index] = Actor(
      id: actor.id,
      name: actor.name,
      role: actor.role,
      birthplace: actor.birthplace,
      bio: actor.bio,
      photoUrl: actor.photoUrl,
      movieIds: actor.movieIds,
      isFollowing: !actor.isFollowing,
    );
  }

  @override
  Future<List<Movie>> getActorFilmography(String actorId) async {
    final actor = await getActorById(actorId);
    if (actor == null) return [];
    return FakeDataSource.movies
        .where((m) => actor.movieIds.contains(m.id))
        .toList();
  }
}

class FakeForumService implements ForumService {
  @override
  Future<List<ForumTopic>> getTopics({String? movieId}) async {
    if (movieId != null) {
      return FakeDataSource.topics.where((t) => t.movieId == movieId).toList();
    }
    return FakeDataSource.topics;
  }

  @override
  Future<ForumTopic?> getTopicById(String id) async {
    try {
      return FakeDataSource.topics.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ForumTopic> createTopic(ForumTopic topic) async {
    FakeDataSource.topics.insert(0, topic);
    return topic;
  }

  @override
  Future<List<ForumMessage>> getMessagesForTopic(String topicId) async {
    return FakeDataSource.messages.where((m) => m.topicId == topicId).toList();
  }

  @override
  Future<bool> postMessage(
    ForumMessage message, {
    required int userMessageCountLastMinute,
  }) async {
    if (userMessageCountLastMinute >= 5) {
      return false; // Anti-spam: max 5 messages per minute
    }
    FakeDataSource.messages.add(message);
    return true;
  }

  @override
  Future<void> likeMessage(String messageId) async {
    // like logic
  }

  @override
  Future<void> reportMessage(
    String targetId,
    String excerpt,
    String reason,
    String reporterId,
  ) async {
    FakeDataSource.reports.add(
      ForumReport(
        id: 'fr_${DateTime.now().millisecondsSinceEpoch}',
        targetId: targetId,
        targetExcerpt: excerpt,
        reason: reason,
        reporterId: reporterId,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> reportTopic(String targetId, String reason) async {
    final topic = await getTopicById(targetId);
    if (topic == null) return;
    FakeDataSource.reports.add(
      ForumReport(
        id: 'fr_${DateTime.now().millisecondsSinceEpoch}',
        targetId: targetId,
        targetExcerpt: topic.title,
        reason: reason,
        reporterId: '',
        targetType: 'topic',
        targetAuthorId: topic.authorId,
        targetAuthorNickname: topic.authorNickname,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<ForumReport>> getModerationReports() async =>
      FakeDataSource.reports;

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    FakeDataSource.reports.removeWhere((report) => report.id == reportId);
  }

  @override
  Future<List<ForumRestriction>> getActiveRestrictions() async => const [];

  @override
  Future<void> liftRestriction(String restrictionId) async {}
}

// Riverpod Providers for all contracts
final userDirectoryProvider = Provider<UserDirectory>(
  (ref) => FakeUserDirectory(),
);
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => FakeSettingsService(),
);
final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  final apiKey = dotenv.isInitialized
      ? dotenv.env['TMDB_API_KEY']?.trim() ?? ''
      : '';
  final repository = TmdbMovieRepository(apiKey: apiKey);
  ref.onDispose(repository.close);
  return repository;
});
final reviewServiceProvider = backendReviewServiceProvider;
final watchlistServiceProvider = backendWatchlistServiceProvider;
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return BackendRecommendationService(
    movies: ref.watch(movieRepositoryProvider),
    actors: ref.watch(actorRepositoryProvider),
    watchlists: ref.watch(watchlistServiceProvider),
    reviewService: ref.watch(reviewServiceProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});
final actorRepositoryProvider = Provider<ActorRepository>(
  (ref) => TmdbActorRepository(
    ref.watch(movieRepositoryProvider),
    ref.watch(apiClientProvider),
  ),
);
final forumServiceProvider = backendForumServiceProvider;
