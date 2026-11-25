// Status login aplikasi (pengguna yang sedang masuk) untuk dibaca layar lewat Provider.
// Alur: layar → AuthProvider → AuthRepository → ApiClient → backend.
import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/api_user.dart';

/// Menyimpan pengguna yang sedang login dan memberi tahu pendengar (layar, keranjang di main.dart)
/// setiap kali status login berubah.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);
  final AuthRepository _repo;

  ApiUser? _user;
  /// Pengguna yang sedang login, atau null bila tamu.
  ApiUser? get user => _user;

  /// True bila ada pengguna yang login.
  bool get isLoggedIn => _user != null;

  /// Memuat pengguna dari token tersimpan (GET /me lewat repository), dipanggil saat splash.
  /// Tidak melempar galat: bila gagal, aplikasi lanjut sebagai tamu.
  Future<void> load() async {
    try {
      _user = await _repo.currentUser();
    } catch (_) {
      // Galat jaringan: tetap sebagai tamu, token dipertahankan.
    }
    notifyListeners();
  }

  /// Login dengan email/HP dan sandi; melempar [ApiException] dari repository bila gagal.
  Future<void> login(String identifier, String password) async {
    _user = await _repo.login(identifier: identifier, password: password);
    notifyListeners();
  }

  /// Keluar di server dan lokal, lalu mengosongkan status login.
  Future<void> logout() async {
    await _repo.logout();
    clear();
  }

  /// Mengosongkan status login tanpa memanggil server (mis. setelah sesi dinyatakan tidak valid).
  void clear() {
    _user = null;
    notifyListeners();
  }
}
