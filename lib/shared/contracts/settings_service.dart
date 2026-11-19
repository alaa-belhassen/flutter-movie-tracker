class AppSettings {
  final String themeMode; // 'cinemaRed' or 'light'
  final String language; // 'EN' or 'FR'
  final String country; // 'US', 'FR', etc.

  const AppSettings({
    this.themeMode = 'cinemaRed',
    this.language = 'EN',
    this.country = 'US',
  });

  AppSettings copyWith({String? themeMode, String? language, String? country}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      country: country ?? this.country,
    );
  }
}

abstract class SettingsService {
  Future<AppSettings> getSettings();
  Future<void> updateSettings(AppSettings settings);
}
