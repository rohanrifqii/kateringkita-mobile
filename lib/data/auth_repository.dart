// Repository akun pelanggan: login, daftar, keluar, lupa/reset sandi, ubah profil & sandi, titik temu favorit, dan foto profil.
// Alur: layar → AuthProvider → AuthRepository → ApiClient → backend REST KateringKita.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/api_user.dart';
import 'token_store.dart';

/// Akun pelanggan lewat REST backend. Token & email sesi disimpan di
/// [TokenStore] (secure storage).
class AuthRepository {
  AuthRepository(this._api, {this.onSessionInvalid, http.Client? uploadClient})
      // ignore: prefer_initializing_formals
      : _uploadClient = uploadClient;
  final ApiClient _api;

  /// Klien polos untuk PUT foto ke URL presign R2 (tanpa header Authorization
  /// aplikasi). null: klien baru per unggahan.
  final http.Client? _uploadClient;

  /// Batas ukuran foto profil, sama dengan server.
  static const int avatarMaxBytes = 5242880;

  /// Ekstensi berkas yang diterima → content type yang dikirim ke server.
  static const _avatarTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const _uploadTimeout = Duration(seconds: 60);
  static const _uploadFailed = 'Gagal mengunggah foto. Coba lagi.';

  /// Dipanggil saat [currentUser] mendapati sesi tidak valid (401) dan token
  /// sudah dihapus, supaya status login aplikasi ikut dibersihkan. Hanya
  /// membersihkan state, tanpa navigasi (aman saat splash: lanjut sebagai tamu).
  final void Function()? onSessionInvalid;

  /// POST /auth/login dengan [identifier] (email atau no HP) dan [password], sebagai klien `mobile`.
  ///
  /// Bila berhasil, token dan email disimpan ke [TokenStore] lalu data pengguna dikembalikan.
  /// Sandi salah tidak memicu penanganan 401 global; [ApiException] diteruskan ke pemanggil.
  Future<ApiUser> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _api.post('/auth/login',
        handleUnauthorized: false,
        body: {
          'identifier': identifier,
          'password': password,
          'client': 'mobile',
        });
    final data = res.data as Map<String, dynamic>;
    final user = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    // Token asli dari server disimpan; ApiClient membacanya untuk permintaan berikutnya.
    await TokenStore.saveSession(
        data['token'] as String, user.email ?? identifier);
    return user;
  }

  /// POST /auth/customer/register: mendaftarkan akun pelanggan baru.
  /// Backend tidak mengembalikan token saat daftar; panggil [login] sesudahnya.
  /// Melempar [ApiException] (mis. galat per kolom bila email/HP sudah dipakai).
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.post('/auth/customer/register', handleUnauthorized: false, body: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
  }

  /// GET /me: data pengguna dari token yang tersimpan.
  ///
  /// null bila tidak ada token atau sesi sudah tidak valid (401); pada 401 token dihapus dan
  /// [onSessionInvalid] dipanggil. Galat lain (mis. jaringan) dilempar ulang.
  Future<ApiUser?> currentUser() async {
    final token = await TokenStore.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final res = await _api.get('/me', handleUnauthorized: false);
      return _userFrom(res);
    } on ApiException catch (e) {
      if (e.status == 401) {
        await TokenStore.logout();
        onSessionInvalid?.call();
        return null;
      }
      rethrow;
    }
  }

  /// POST /auth/logout lalu menghapus token lokal. Galat dari server diabaikan supaya
  /// pengguna tetap bisa keluar walau sedang luring.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', handleUnauthorized: false);
    } catch (_) {
      // Abaikan galat jaringan/401: sesi lokal tetap dihapus.
    }
    await TokenStore.logout();
  }

  /// POST /auth/password/forgot: meminta kode reset sandi dikirim ke [email].
  /// Mengembalikan pesan dari server (string kosong bila tidak ada).
  Future<String> forgotPassword(String email) async {
    final res = await _api.post('/auth/password/forgot',
        handleUnauthorized: false, body: {'email': email});
    return (res.data as Map<String, dynamic>)['message'] as String? ?? '';
  }

  /// POST /auth/password/verify: memeriksa [code] reset sandi untuk [email].
  /// Melempar [ApiException] bila kode salah atau kedaluwarsa.
  Future<void> verifyCode({required String email, required String code}) async {
    await _api.post('/auth/password/verify',
        handleUnauthorized: false, body: {'email': email, 'code': code});
  }

  /// POST /auth/password/reset: menyetel sandi baru [password] memakai [code] yang sudah diverifikasi.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _api.post('/auth/password/reset',
        handleUnauthorized: false,
        body: {'email': email, 'code': code, 'password': password});
  }

  /// PATCH /me. Mengubah email/HP butuh [currentPassword] di server.
  ///
  /// `email` hanya dikirim bila [newEmail] berbeda dari [oldEmail] (tanpa beda huruf besar/kecil).
  /// Bila server mengembalikan email, email sesi di [TokenStore] ikut diperbarui. [userId]
  /// tidak dipakai oleh metode ini. Melempar [ApiException] bila gagal.
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

  /// PATCH /me `{favorite_pickup_point_id}`; null menghapus favorit. Server
  /// menolak titik yang tidak aktif (400, kolom favorite_pickup_point_id).
  Future<ApiUser> setFavoritePickupPoint(int? pickupPointId) async =>
      _userFrom(await _api.patch('/me',
          body: {'favorite_pickup_point_id': pickupPointId}));

  /// PUT /me/password. Return null bila sukses, atau pesan galat dari server.
  Future<String?> changePassword({
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

  /// Content type foto dari ekstensi [fileName], atau null bila bukan
  /// JPG/PNG/WebP.
  static String? avatarContentType(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return _avatarTypes[fileName.substring(dot + 1).toLowerCase()];
  }

  /// Ganti foto profil: minta URL presign (POST /me/avatar), PUT berkas ke
  /// penyimpanan, lalu simpan public_url ke profil (PATCH /me). Tipe & ukuran
  /// dicek dulu tanpa jaringan. Galat berupa [ApiException] dengan pesan siap
  /// tampil.
  Future<ApiUser> uploadAvatar({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final type = avatarContentType(fileName);
    if (type == null) {
      throw _invalid('content_type', 'Format foto harus JPG, PNG, atau WebP.');
    }
    if (bytes.isEmpty) throw _invalid('size', 'Ukuran foto tidak valid.');
    if (bytes.length > avatarMaxBytes) {
      throw _invalid('size', 'Ukuran foto maksimal 5 MB.');
    }
    final res = await _withFieldMessage(
      () => _api.post('/me/avatar',
          body: {'content_type': type, 'size': bytes.length}),
      const ['content_type', 'size'],
    );
    final data = res.data as Map<String, dynamic>;
    await _putToStorage(Uri.parse(data['upload_url'] as String), type, bytes);
    return _setAvatarUrl(data['public_url'] as String);
  }

  /// Hapus foto profil (server menyimpan "" sebagai null).
  Future<ApiUser> removeAvatar() => _setAvatarUrl('');

  /// PATCH /me {avatar_url}; pesan galat kolom avatar_url dipakai bila ada.
  Future<ApiUser> _setAvatarUrl(String url) async =>
      _userFrom(await _withFieldMessage(
        () => _api.patch('/me', body: {'avatar_url': url}),
        const ['avatar_url'],
      ));

  /// PUT mentah ke URL presign. Content-Type & Content-Length ikut
  /// ditandatangani, jadi harus persis [type] dan panjang [bytes].
  Future<void> _putToStorage(Uri url, String type, Uint8List bytes) async {
    final client = _uploadClient ?? http.Client();
    final req = http.Request('PUT', url)
      ..headers['Content-Type'] = type
      ..bodyBytes = bytes;
    var status = 0;
    try {
      final res = await client.send(req).timeout(_uploadTimeout);
      await res.stream.drain<void>();
      status = res.statusCode;
    } catch (_) {
      // Jaringan putus / waktu habis: sama dengan gagal unggah.
    } finally {
      if (_uploadClient == null) client.close();
    }
    if (status < 200 || status >= 300) {
      throw ApiException(
          status: status, code: 'UPLOAD_FAILED', message: _uploadFailed);
    }
  }

  /// Galat validasi server memakai pesan kolom pertama dari [keys], lebih
  /// jelas daripada "Data tidak valid.".
  Future<T> _withFieldMessage<T>(
      Future<T> Function() call, List<String> keys) async {
    try {
      return await call();
    } on ApiException catch (e) {
      for (final k in keys) {
        final m = e.field(k);
        if (m != null) {
          throw ApiException(
              status: e.status, code: e.code, message: m, fields: e.fields);
        }
      }
      rethrow;
    }
  }

  /// Galat validasi lokal berbentuk sama dengan galat 400 dari server.
  static ApiException _invalid(String field, String message) => ApiException(
        status: 400,
        code: 'VALIDATION_ERROR',
        message: message,
        fields: {
          field: [message]
        },
      );

  /// Mengambil objek `user` dari balasan server.
  ApiUser _userFrom(ApiResponse res) => ApiUser.fromJson(
      (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
}
