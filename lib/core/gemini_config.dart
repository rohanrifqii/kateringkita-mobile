import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Konfigurasi Internal Google Gemini AI untuk KateringKita.
/// End-user TIDAK perlu memasukkan API Key — semua berjalan otomatis di balik layar.
class GeminiConfig {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'google_gemini_api_key';

  /// Daftar model Google AI Studio terbaru (dicoba berurutan secara otomatis)
  static const List<String> candidateModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
  ];

  /// Developer dapat menaruh API Key Google AI Studio (AIzaSy...) di sini
  /// atau menjalankan lewat `--dart-define=GEMINI_API_KEY=AIzaSy...`
  static const String developerApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Mengambil API Key secara otomatis di balik layar
  static Future<String?> getApiKey() async {
    if (developerApiKey.trim().isNotEmpty) {
      return developerApiKey.trim();
    }

    try {
      final savedKey = await _storage.read(key: _storageKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (_) {}

    return null;
  }

  static Future<void> saveApiKey(String key) async {
    await _storage.write(key: _storageKey, value: key.trim());
  }
}
