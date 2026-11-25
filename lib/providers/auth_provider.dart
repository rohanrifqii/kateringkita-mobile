// Status login aplikasi (pengguna yang sedang masuk) untuk dibaca layar lewat Provider.
// Alur: layar → AuthProvider → AuthRepository → ApiClient → backend.
import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../data/auth_repository.dart';
import '../models/api_user.dart';

/// Menyimpan pengguna yang sedang login dan memberi tahu pendengar (layar; di main.dart keranjang,
/// favorit, dan lencana notifikasi dikosongkan saat keluar)
/// setiap kali status login berubah.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);
  final AuthRepository _repo;

  ApiUser? _user;

  /// Pemuatan sesi tersimpan yang sedang/sudah berjalan; null bila belum dimulai
  /// atau sesudah login/keluar.
  Future<void>? _loading;

  /// Naik setiap login/keluar; hasil GET /me yang datang sesudahnya diabaikan.
  int _sessionVersion = 0;

  /// Pengguna yang sedang login, atau null bila tamu.
  ApiUser? get user => _user;

  /// True bila ada pengguna yang login.
  bool get isLoggedIn => _user != null;

  /// Selesai saat pemuatan sesi dari [load] selesai (langsung selesai bila [load] belum
  /// dipanggil). Ditunggu sebelum memeriksa [isLoggedIn] di halaman yang dibuka saat
  /// web dimuat ulang, karena GET /me dari splash mungkin belum kembali.
  Future<void> get ready => _loading ?? Future<void>.value();

  /// Memuat pengguna dari token tersimpan (GET /me lewat repository), dipanggil saat splash.
  /// Panggilan berikutnya memakai pemuatan yang sama. Tidak melempar galat: bila gagal,
  /// aplikasi lanjut sebagai tamu.
  Future<void> load() => _loading ??= _loadCurrentUser();

  // Satu kali GET /me; hasilnya dibuang bila pengguna login/keluar selama menunggu.
  Future<void> _loadCurrentUser() async {
    final versionAtStart = _sessionVersion;
    try {
      final loadedUser = await _repo.currentUser();
      if (versionAtStart == _sessionVersion) _user = loadedUser;
    } catch (_) {
      // Galat jaringan: tetap sebagai tamu, token dipertahankan.
    }
    notifyListeners();
  }

  // Login/keluar: pemuatan sesi lama tidak berlaku lagi.
  void _resetLoading() {
    _loading = null;
    _sessionVersion++;
  }

  /// Login dengan email/HP dan sandi; melempar [ApiException] dari repository bila gagal.
  Future<void> login(String identifier, String password) async {
    _user = await _repo.login(identifier: identifier, password: password);
    _resetLoading();
    notifyListeners();
  }

  /// Simpan titik temu favorit ke profil lewat PATCH /me (dipakai beranda &
  /// checkout); null menghapusnya. Gagal: [ApiException], user tidak berubah.
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

  /// Keluar: POST /auth/logout (galat server diabaikan), hapus token lokal,
  /// lalu kosongkan status login.
  Future<void> logout() async {
    await _repo.logout();
    clear();
  }

  /// Mengosongkan status login tanpa memanggil server (mis. setelah sesi dinyatakan tidak valid).
  void clear() {
    _user = null;
    _resetLoading();
    notifyListeners();
  }

  /// Ganti data pengguna dengan balasan server terbaru lalu beri tahu layar.
  void _setUser(ApiUser user) {
    _user = user;
    notifyListeners();
  }

  /// Pengguna yang sedang login; tamu langsung ditolak dengan galat 401 lokal.
  ApiUser _requireUser() =>
      _user ??
      (throw const ApiException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Masuk dulu untuk mengubah profil.'));
}
