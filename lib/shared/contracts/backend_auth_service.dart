import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'auth_service.dart';

class BackendAuthService implements AuthService {
  BackendAuthService({required this.apiClient, required this.storage});

  static const _tokenKey = 'movietracker_access_token';

  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  @override
  Future<UserProfile?> getCurrentUser() async {
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;
    apiClient.accessToken = token;
    try {
      final response = await apiClient.request('GET', 'auth/me');
      return _parseUser(response['user']);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearToken();
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile> signIn(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    final response = await apiClient.request(
      'POST',
      'auth/login',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
        'rememberMe': rememberMe,
      },
    );
    return _saveSession(response, persist: rememberMe);
  }

  @override
  Future<UserProfile> signUp(
    String email,
    String password,
    String nickname, {
    required String country,
    required List<String> favoriteGenres,
  }) async {
    final response = await apiClient.request(
      'POST',
      'auth/register',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
        'country': country,
        'favoriteGenres': favoriteGenres,
      },
    );
    return _saveSession(response, persist: true);
  }

  @override
  Future<UserProfile> updateProfile({
    required String nickname,
    required String country,
    required List<String> favoriteGenres,
  }) async {
    final response = await apiClient.request(
      'PATCH',
      'users/me',
      body: {
        'nickname': nickname.trim(),
        'country': country,
        'favoriteGenres': favoriteGenres,
      },
    );
    return _parseUser(response['user']);
  }

  @override
  Future<void> signOut() async {
    try {
      if (apiClient.accessToken != null) {
        await apiClient.request('POST', 'auth/logout');
      }
    } finally {
      await _clearToken();
    }
  }

  Future<UserProfile> _saveSession(
    Map<String, dynamic> response, {
    required bool persist,
  }) async {
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('The API did not return a session token.');
    }
    apiClient.accessToken = token;
    if (persist) {
      await storage.write(key: _tokenKey, value: token);
    } else {
      await storage.delete(key: _tokenKey);
    }
    return _parseUser(response['user']);
  }

  UserProfile _parseUser(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('The API returned an invalid user profile.');
    }
    final genres = value['favoriteGenres'];
    return UserProfile(
      id: value['id'] as String,
      email: value['email'] as String,
      nickname: value['nickname'] as String,
      country: value['country'] as String? ?? 'US',
      favoriteGenres: genres is List
          ? genres.whereType<String>().toList(growable: false)
          : const [],
      isModerator: value['isModerator'] == true,
    );
  }

  Future<void> _clearToken() async {
    apiClient.accessToken = null;
    await storage.delete(key: _tokenKey);
  }
}
