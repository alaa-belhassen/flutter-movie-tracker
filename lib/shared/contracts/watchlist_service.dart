class CustomList {
  final String id;
  final String title;
  final String userId;
  final List<String> movieIds;
  final bool isShared;
  final List<String> memberIds;
  final List<CustomListMember> members;

  const CustomList({
    required this.id,
    required this.title,
    required this.userId,
    required this.movieIds,
    this.isShared = false,
    this.memberIds = const [],
    this.members = const [],
  });
}

class CustomListMember {
  const CustomListMember({
    required this.id,
    required this.nickname,
    required this.email,
  });

  final String id;
  final String nickname;
  final String email;
}

class MovieRecommendationResult {
  final String movieId;
  final String title;
  const MovieRecommendationResult({required this.movieId, required this.title});
}

abstract class WatchlistService {
  Future<List<String>> getWatchlist(String userId);
  Future<List<String>> getFavorites(String userId);
  Future<void> toggleWatchlist(String userId, String movieId);
  Future<void> toggleFavorite(String userId, String movieId);
  Future<void> addFavorite(String userId, String movieId);
  Future<List<CustomList>> getCustomLists(String userId);
  Future<void> saveCustomList(CustomList list);
  Future<void> deleteCustomList(String listId);
  Future<CustomList> getCustomList(String listId);
  Future<CustomList> inviteToList(String listId, String email);
  Future<void> removeListMember(String listId, String memberId);
  Future<CustomList> addMovieToList(String listId, String movieId);
  Future<void> removeMovieFromList(String listId, String movieId);
  Future<void> leaveSharedList(String listId);
  Future<MovieRecommendationResult?> tonightPicker({
    required String userId,
    required int maxDurationMinutes,
    String? genre,
  });
}
