import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Rahasia (token, email sesi, password) disimpan terenkripsi:
/// Keychain (iOS) / Keystore (Android).
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _sessionEmailKey = 'session_email';
  static String _pwdKey(String email) => 'pwd_${email.trim().toLowerCase()}';

  // ---------------- SESSION ----------------
  /// Simpan token + email user yang sedang login.
  static Future<void> saveSession(String token, String email) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
        key: _sessionEmailKey, value: email.trim().toLowerCase());
  }

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<String?> readSessionEmail() =>
      _storage.read(key: _sessionEmailKey);

  /// Logout hanya menghapus sesi. Password akun TIDAK ikut terhapus
  /// supaya user tetap bisa login lagi.
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionEmailKey);
  }

  // ---------------- PASSWORD ----------------
  static Future<void> savePassword(String email, String password) =>
      _storage.write(key: _pwdKey(email), value: password);

  static Future<String?> readPassword(String email) =>
      _storage.read(key: _pwdKey(email));
}