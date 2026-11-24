// Penyimpanan sesi login (token akses dan email) di perangkat. ApiClient membaca token dari sini
// untuk header Authorization; AuthRepository menulis/menghapusnya saat login dan logout.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Rahasia (token, email sesi) disimpan terenkripsi:
/// Keychain (iOS) / Keystore (Android).
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _sessionEmailKey = 'session_email';

  /// Simpan token + email user yang sedang login.
  static Future<void> saveSession(String token, String email) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
        key: _sessionEmailKey, value: email.trim().toLowerCase());
  }

  /// Token akses yang tersimpan, atau null bila belum login.
  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Email pengguna yang sedang login (huruf kecil), atau null bila belum login.
  static Future<String?> readSessionEmail() =>
      _storage.read(key: _sessionEmailKey);

  /// Logout menghapus sesi lokal (token dan email).
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionEmailKey);
  }
}
