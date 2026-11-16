class ApiConfig {
  /// Nilai `--dart-define=API_BASE_URL`. Boleh relatif (mis. `/api/v1`) untuk
  /// build web demo: API lalu mengikuti alamat halaman yang sedang dibuka,
  /// jadi build yang sama tetap jalan walau IP WiFi laptop berubah.
  static const String _raw = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://ketring-45f82aef1ca0.herokuapp.com/api/v1');

  static String get baseUrl => resolve(_raw, Uri.base);

  /// Alamat lengkap dibiarkan; alamat relatif digabung dengan [page].
  static String resolve(String raw, Uri page) =>
      Uri.parse(raw).hasScheme ? raw : page.resolve(raw).toString();
}
