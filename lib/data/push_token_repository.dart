// Isi file: repository token push perangkat (daftar dan hapus) ke backend.
// Alur: layanan push → PushTokenRepository → ApiClient → backend (/me/push-token).
import '../api/api_client.dart';

/// Token push (FCM) perangkat ini lewat REST backend (butuh sesi).
class PushTokenRepository {
  PushTokenRepository(this._api);

  final ApiClient _api;

  /// PUT /me/push-token `{token, platform}`: daftarkan [token] untuk akun ini.
  /// [platform]: `android` | `web`. 401 tidak memicu logout global; galat
  /// diteruskan ke pemanggil.
  Future<void> register(String token, String platform) async {
    await _api.put('/me/push-token',
        body: {'token': token, 'platform': platform},
        handleUnauthorized: false);
  }

  /// DELETE /me/push-token: lepas token perangkat ini dari akun (saat keluar).
  Future<void> unregister() async {
    await _api.delete('/me/push-token', handleUnauthorized: false);
  }
}
