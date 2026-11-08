import 'app_database.dart';
import 'token_store.dart';

/// Menggabungkan 2 jenis local storage untuk fitur akun:
/// - Drift (SQLite)  -> data profil: nama, email, no HP
/// - Secure Storage  -> password & token sesi (terenkripsi)
class AuthRepository {
  AuthRepository(this._db);
  final AppDb _db;

  /// Return `null` kalau sukses, atau pesan error.
  Future<String?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final existing = await _db.findUserByEmail(email);
    if (existing != null) return 'Email sudah terdaftar, silakan login.';

    await _db.addUser(fullName: fullName, email: email, phone: phone);
    await TokenStore.savePassword(email, password);
    return null;
  }

  /// Return `null` kalau sukses, atau pesan error.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final user = await _db.findUserByEmail(email);
    if (user == null) return 'Akun belum terdaftar. Silakan daftar dulu.';

    final saved = await TokenStore.readPassword(email);
    if (saved != password) return 'Password salah.';

    // Simulasi token (belum ada backend).
    await TokenStore.saveSession(
      'dev-token-${DateTime.now().millisecondsSinceEpoch}',
      user.email,
    );
    return null;
  }

  /// User yang sedang login (berdasarkan email sesi di secure storage).
  Future<User?> currentUser() async {
    final token = await TokenStore.readToken();
    final email = await TokenStore.readSessionEmail();
    if (token == null || email == null) return null;
    return _db.findUserByEmail(email);
  }

  /// Reset password: simpan password baru ke secure storage
  /// dan pastikan akun user ada di database SQLite.
  Future<String?> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    var user = await _db.findUserByEmail(cleanEmail);
    if (user == null) {
      await _db.addUser(
        fullName: cleanEmail.split('@').first,
        email: cleanEmail,
        phone: '085852157352',
      );
    }
    await TokenStore.savePassword(cleanEmail, newPassword);
    return null;
  }

  /// Update data nama, nomor WhatsApp, dan email user yang sedang login.
  Future<User?> updateProfile({
    required int userId,
    required String oldEmail,
    required String fullName,
    required String phone,
    required String newEmail,
  }) async {
    final cleanOld = oldEmail.trim().toLowerCase();
    final cleanNew = newEmail.trim().toLowerCase();

    await _db.updateUserProfile(
      id: userId,
      fullName: fullName,
      phone: phone,
      email: cleanNew,
    );

    if (cleanNew != cleanOld) {
      final oldPwd = await TokenStore.readPassword(cleanOld);
      if (oldPwd != null) {
        await TokenStore.savePassword(cleanNew, oldPwd);
      }
      final token = await TokenStore.readToken() ??
          'dev-token-${DateTime.now().millisecondsSinceEpoch}';
      await TokenStore.saveSession(token, cleanNew);
    }

    return _db.findUserByEmail(cleanNew);
  }

  /// Ubah password akun dengan verifikasi password lama.
  Future<String?> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final saved = await TokenStore.readPassword(cleanEmail);
    if (saved != null && saved != currentPassword) {
      return 'Password saat ini tidak sesuai.';
    }
    await TokenStore.savePassword(cleanEmail, newPassword);
    return null;
  }

  Future<void> logout() => TokenStore.logout();
}
