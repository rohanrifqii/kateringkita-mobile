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

  Future<void> logout() => TokenStore.logout();
}
