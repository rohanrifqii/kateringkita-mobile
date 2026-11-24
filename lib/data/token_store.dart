import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rahasia (token, email sesi) disimpan terenkripsi:
/// Keychain (iOS) / Keystore (Android).
///
/// Web: flutter_secure_storage butuh WebCrypto (`crypto.subtle`), yang hanya
/// ada di HTTPS/localhost; dibuka lewat IP WiFi (http://192.168.x.x) penyimpanan
/// gagal sehingga daftar/masuk gagal. Di web kunci enkripsinya pun disimpan di
/// localStorage yang sama, jadi web memakai shared_preferences saja.
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static final _web = SharedPreferencesAsync();
  static const _tokenKey = 'access_token';
  static const _sessionEmailKey = 'session_email';

  static Future<void> _write(String key, String value) => kIsWeb
      ? _web.setString(key, value)
      : _storage.write(key: key, value: value);

  static Future<String?> _read(String key) =>
      kIsWeb ? _web.getString(key) : _storage.read(key: key);

  static Future<void> _delete(String key) =>
      kIsWeb ? _web.remove(key) : _storage.delete(key: key);

  /// Simpan token + email user yang sedang login.
  static Future<void> saveSession(String token, String email) async {
    await _write(_tokenKey, token);
    await _write(_sessionEmailKey, email.trim().toLowerCase());
  }

  static Future<String?> readToken() => _read(_tokenKey);

  static Future<String?> readSessionEmail() => _read(_sessionEmailKey);

  /// Logout menghapus sesi lokal (token dan email).
  static Future<void> logout() async {
    await _delete(_tokenKey);
    await _delete(_sessionEmailKey);
  }
}
