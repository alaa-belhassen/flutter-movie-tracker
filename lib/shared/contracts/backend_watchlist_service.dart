import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'watchlist_service.dart';

class BackendWatchlistService implements WatchlistService {
  BackendWatchlistService(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, Set<String>> _movieIdsCache = {};
  final Map<String, bool> _movieIdsLoaded = {};
  final Map<String, Map<String, bool>> _movieOverrides = {};

  CustomList _parseList(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['userId'] is! String ||
        value['movieIds'] is! List) {
      throw const FormatException('The API returned an invalid custom list.');
    }
    final memberIds = value['memberIds'];
    final members = value['members'];
    return CustomList(
      id: value['id'] as String,
      title: value['title'] as String,
      userId: value['userId'] as String,
      movieIds: (value['movieIds'] as List).whereType<String>().toList(
        growable: false,
      ),
      isShared: value['isShared'] == true,
      memberIds: memberIds is List
          ? memberIds.whereType<String>().toList(growable: false)
          : const [],
      members: members is List
          ? members
                .whereType<Map<String, dynamic>>()
                .map(
                  (member) => CustomListMember(
                    id: member['id'] as String,
                    nickname: member['nickname'] as String,
                    email: member['email'] as String,
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  Future<List<String>> _getMovieIds(String path, String userId) async {
    final cacheKey = '$userId:$path';
    final cached = _movieIdsCache[cacheKey];
    if (cached != null && _movieIdsLoaded[cacheKey] == true) {
      return cached.toList(growable: false);
    }

    final response = await _apiClient.request('GET', 'users/me/$path');
    final ids = response['movieIds'];
    if (ids is! List) {
      throw const FormatException('The API returned an invalid movie list.');
    }
    final movieIds = ids.whereType<String>().toSet();
    for (final entry
        in _movieOverrides[cacheKey]?.entries ??
            const <MapEntry<String, bool>>[]) {
      if (entry.value) {
        movieIds.add(entry.key);
      } else {
        movieIds.remove(entry.key);
      }
    }
    _movieIdsCache[cacheKey] = movieIds;
    _movieIdsLoaded[cacheKey] = true;
    return movieIds.toList(growable: false);
  }

  @override
  Future<List<String>> getWatchlist(String userId) =>
      _getMovieIds('watchlist', userId);

  @override
  Future<List<String>> getFavorites(String userId) =>
      _getMovieIds('favorites', userId);

  @override
  Future<void> toggleWatchlist(String userId, String movieId) =>
      _toggleMovie('watchlist', userId, movieId);

  @override
  Future<void> toggleFavorite(String userId, String movieId) =>
      _toggleMovie('favorites', userId, movieId);

  @override
  Future<void> addFavorite(String userId, String movieId) =>
      _setMovie('favorites', userId, movieId, true);

  Future<void> _toggleMovie(String path, String userId, String movieId) async {
    final movieIds = await _getMovieIds(path, userId);
    await _setMovie(path, userId, movieId, !movieIds.contains(movieId));
  }

  Future<void> _setMovie(
    String path,
    String userId,
    String movieId,
    bool shouldAdd,
  ) async {
    final cacheKey = '$userId:$path';
    final movieIds = _movieIdsCache.putIfAbsent(cacheKey, () => <String>{});
    final previousOverride = _movieOverrides[cacheKey]?[movieId];
    final wasPresent = _movieIdsLoaded[cacheKey] == true
        ? movieIds.contains(movieId)
        : previousOverride ?? movieIds.contains(movieId);
    _movieOverrides.putIfAbsent(cacheKey, () => {})[movieId] = shouldAdd;
    if (shouldAdd) {
      movieIds.add(movieId);
    } else {
      movieIds.remove(movieId);
    }
    _movieIdsCache[cacheKey] = movieIds;

    try {
      final encodedId = Uri.encodeComponent(movieId);
      await _apiClient.request(
        shouldAdd ? 'PUT' : 'DELETE',
        'users/me/$path/$encodedId',
      );
    } catch (_) {
      if (_movieOverrides[cacheKey]?[movieId] == shouldAdd) {
        if (previousOverride == null) {
          _movieOverrides[cacheKey]?.remove(movieId);
        } else {
          _movieOverrides[cacheKey]?[movieId] = previousOverride;
        }
        if (wasPresent) {
          movieIds.add(movieId);
        } else {
          movieIds.remove(movieId);
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<CustomList>> getCustomLists(String userId) async {
    final response = await _apiClient.request('GET', 'users/me/lists');
    final rows = response['lists'];
    if (rows is! List) {
      throw const FormatException('The API returned invalid custom lists.');
    }
    return rows.map(_parseList).toList(growable: false);
  }

  @override
  Future<void> saveCustomList(CustomList list) async {
    await _apiClient.request(
      list.id.startsWith('local_') ? 'POST' : 'PUT',
      list.id.startsWith('local_')
          ? 'users/me/lists'
          : 'users/me/lists/${Uri.encodeComponent(list.id)}',
      body: {
        'id': list.id,
        'title': list.title,
        'movieIds': list.movieIds,
        'isShared': list.isShared,
      },
    );
  }

  @override
  Future<void> deleteCustomList(String listId) async {
    await _apiClient.request(
      'DELETE',
      'users/me/lists/${Uri.encodeComponent(listId)}',
    );
  }

  @override
  Future<CustomList> getCustomList(String listId) async {
    final response = await _apiClient.request(
      'GET',
      'lists/${Uri.encodeComponent(listId)}',
    );
    return _parseList(response['list']);
  }

  @override
  Future<CustomList> inviteToList(String listId, String email) async {
    await _apiClient.request(
      'POST',
      'users/me/lists/${Uri.encodeComponent(listId)}/invitations',
      body: {'email': email.trim()},
    );
    return getCustomList(listId);
  }

  @override
  Future<void> removeListMember(String listId, String memberId) async {
    await _apiClient.request(
      'DELETE',
      'users/me/lists/${Uri.encodeComponent(listId)}/members/${Uri.encodeComponent(memberId)}',
    );
  }

  @override
  Future<CustomList> addMovieToList(String listId, String movieId) async {
    final response = await _apiClient.request(
      'PUT',
      'lists/${Uri.encodeComponent(listId)}/movies/${Uri.encodeComponent(movieId)}',
    );
    return _parseList(response['list']);
  }

  @override
  Future<void> removeMovieFromList(String listId, String movieId) async {
    await _apiClient.request(
      'DELETE',
      'lists/${Uri.encodeComponent(listId)}/movies/${Uri.encodeComponent(movieId)}',
    );
  }

  @override
  Future<void> leaveSharedList(String listId) async {
    await _apiClient.request(
      'DELETE',
      'users/me/lists/${Uri.encodeComponent(listId)}/leave',
    );
  }

  @override
  Future<MovieRecommendationResult?> tonightPicker({
    required String userId,
    required int maxDurationMinutes,
    String? genre,
  }) async => null;
}

final backendWatchlistServiceProvider = Provider<WatchlistService>(
  (ref) => BackendWatchlistService(ref.watch(apiClientProvider)),
);
