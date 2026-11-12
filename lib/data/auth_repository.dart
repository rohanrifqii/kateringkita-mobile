import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/api_user.dart';
import 'token_store.dart';

/// Akun pelanggan lewat REST backend. Token & email sesi disimpan di
/// [TokenStore] (secure storage).
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<ApiUser> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', body: {
      'identifier': identifier,
      'password': password,
      'client': 'mobile',
    });
    final data = res.data as Map<String, dynamic>;
    final user = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStore.saveSession(
        data['token'] as String, user.email ?? identifier);
    return user;
  }

  /// Backend tidak mengembalikan token saat daftar; panggil [login] sesudahnya.
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.post('/auth/customer/register', body: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
  }

  /// null bila tidak ada token atau sesi sudah tidak valid (401).
  Future<ApiUser?> currentUser() async {
    final token = await TokenStore.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final res = await _api.get('/me');
      return _userFrom(res);
    } on ApiException catch (e) {
      if (e.status == 401) {
        await TokenStore.logout();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Abaikan galat jaringan/401: sesi lokal tetap dihapus.
    }
    await TokenStore.logout();
  }

  Future<String> forgotPassword(String email) async {
    final res = await _api.post('/auth/password/forgot', body: {'email': email});
    return (res.data as Map<String, dynamic>)['message'] as String? ?? '';
  }

  Future<void> verifyCode({required String email, required String code}) async {
    await _api
        .post('/auth/password/verify', body: {'email': email, 'code': code});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _api.post('/auth/password/reset',
        body: {'email': email, 'code': code, 'password': password});
  }

  /// PATCH /me. Mengubah email/HP butuh [currentPassword] di server.
  Future<ApiUser> updateProfile({
    required int userId,
    required String oldEmail,
    required String fullName,
    required String phone,
    required String newEmail,
    String? currentPassword,
  }) async {
    final body = <String, dynamic>{'full_name': fullName, 'phone': phone};
    if (newEmail.trim().toLowerCase() != oldEmail.trim().toLowerCase()) {
      body['email'] = newEmail.trim();
    }
    if (currentPassword != null) body['current_password'] = currentPassword;
    final res = await _api.patch('/me', body: body);
    final user = _userFrom(res);
    if (user.email != null) {
      final token = await TokenStore.readToken();
      if (token != null) await TokenStore.saveSession(token, user.email!);
    }
    return user;
  }

  /// PUT /me/password. Return null bila sukses, atau pesan galat dari server.
  Future<String?> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.put('/me/password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      return null;
    } on ApiException catch (e) {
      return e.field('current_password') ??
          e.field('new_password') ??
          e.message;
    }
  }

  ApiUser _userFrom(ApiResponse res) => ApiUser.fromJson(
      (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
}
