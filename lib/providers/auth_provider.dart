import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../data/auth_repository.dart';
import '../models/api_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);
  final AuthRepository _repo;

  ApiUser? _user;
  ApiUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> load() async {
    try {
      _user = await _repo.currentUser();
    } catch (_) {
      // Galat jaringan: tetap sebagai tamu, token dipertahankan.
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _user = await _repo.login(identifier: identifier, password: password);
    notifyListeners();
  }

  /// Simpan titik temu favorit ke profil (dipakai beranda & checkout).
  Future<void> setFavoritePickupPoint(int? pickupPointId) async {
    _setUser(await _repo.setFavoritePickupPoint(pickupPointId));
  }

  /// Ubah nama/WA/email (PATCH /me). Server meminta [currentPassword] bila
  /// email atau nomor berubah. Gagal: [ApiException], user tidak berubah.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String email,
    String? currentPassword,
  }) async {
    final u = _requireUser();
    _setUser(await _repo.updateProfile(
      userId: u.id,
      oldEmail: u.email ?? '',
      fullName: fullName,
      phone: phone,
      newEmail: email,
      currentPassword: currentPassword,
    ));
  }

  /// Ganti foto profil (lihat [AuthRepository.uploadAvatar]).
  Future<void> uploadAvatar({
    required String fileName,
    required Uint8List bytes,
  }) async {
    _requireUser();
    _setUser(await _repo.uploadAvatar(fileName: fileName, bytes: bytes));
  }

  /// Hapus foto profil, kembali ke inisial nama.
  Future<void> removeAvatar() async {
    _requireUser();
    _setUser(await _repo.removeAvatar());
  }

  Future<void> logout() async {
    await _repo.logout();
    clear();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }

  void _setUser(ApiUser user) {
    _user = user;
    notifyListeners();
  }

  ApiUser _requireUser() =>
      _user ??
      (throw const ApiException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Masuk dulu untuk mengubah profil.'));
}
