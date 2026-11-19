class AppUser {
  final String id;
  final String email;
  final String nickname;
  final String country;
  final String photoUrl;
  final bool isModerator;

  const AppUser({
    required this.id,
    required this.email,
    required this.nickname,
    required this.country,
    this.photoUrl = '',
    this.isModerator = false,
  });
}

abstract class UserDirectory {
  Future<List<AppUser>> getAllUsers();
  Future<AppUser?> getUserById(String id);
  Future<bool> isNicknameUnique(String nickname);
  Future<void> updateUser(AppUser user);
}
