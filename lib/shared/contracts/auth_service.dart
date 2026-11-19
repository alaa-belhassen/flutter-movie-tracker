import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'backend_auth_service.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.country,
    this.favoriteGenres = const [],
    this.isModerator = false,
  });

  final String id;
  final String email;
  final String nickname;
  final String country;
  final List<String> favoriteGenres;
  final bool isModerator;
}

abstract interface class AuthService {
  Future<UserProfile?> getCurrentUser();
  Future<UserProfile> signIn(
    String email,
    String password, {
    bool rememberMe = true,
  });
  Future<void> signOut();
  Future<UserProfile> signUp(
    String email,
    String password,
    String nickname, {
    required String country,
    required List<String> favoriteGenres,
  });
  Future<UserProfile> updateProfile({
    required String nickname,
    required String country,
    required List<String> favoriteGenres,
  });
}

final authServiceProvider = Provider<AuthService>((ref) {
  return BackendAuthService(
    apiClient: ref.watch(apiClientProvider),
    storage: const FlutterSecureStorage(),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
      return AuthController(ref.watch(authServiceProvider));
    });

final currentUserProvider = Provider<UserProfile?>(
  (ref) => ref.watch(authControllerProvider).valueOrNull,
);

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  AuthController(this._service) : super(const AsyncLoading()) {
    Future<void>.microtask(_restoreSession);
  }

  final AuthService _service;

  Future<void> _restoreSession() async {
    try {
      state = AsyncData(await _service.getCurrentUser());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<UserProfile> signIn(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _service.signIn(
        email,
        password,
        rememberMe: rememberMe,
      );
      state = AsyncData(user);
      return user;
    } catch (error) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<UserProfile> signUp(
    String email,
    String password,
    String nickname, {
    required String country,
    required List<String> favoriteGenres,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _service.signUp(
        email,
        password,
        nickname,
        country: country,
        favoriteGenres: favoriteGenres,
      );
      state = AsyncData(user);
      return user;
    } catch (error) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({
    required String nickname,
    required String country,
    required List<String> favoriteGenres,
  }) async {
    final previousUser = state.valueOrNull;
    if (previousUser == null) {
      throw StateError('Sign in before updating your profile.');
    }
    try {
      final user = await _service.updateProfile(
        nickname: nickname,
        country: country,
        favoriteGenres: favoriteGenres,
      );
      state = AsyncData(user);
      return user;
    } catch (error) {
      state = AsyncData(previousUser);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _service.signOut();
    } finally {
      state = const AsyncData(null);
    }
  }
}
