// Konfigurasi alamat backend REST KateringKita yang dipakai ApiClient.
// Alur: layar → provider → repository → ApiClient (memakai alamat dari sini) → backend.

/// Kumpulan pengaturan koneksi ke backend.
class ApiConfig {
  /// Alamat dasar API (sudah termasuk `/api/v1`).
  ///
  /// Bisa diganti saat build atau run dengan `--dart-define=API_BASE_URL=<alamat>`;
  /// bila tidak diisi, dipakai alamat server Heroku di bawah.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://ketring-45f82aef1ca0.herokuapp.com/api/v1');
}
