// Model data akun pengguna sebagaimana dikirim backend REST KateringKita (format JSON snake_case).
// Di cabang ini belum dipakai layar mana pun; disiapkan untuk fitur akun yang memakai ApiClient.

/// Data satu akun pengguna dari backend. [ApiUser.fromJson] mengubah objek JSON menjadi kelas ini.
class ApiUser {
  final int id;

  /// Peran akun menurut backend (teks apa adanya dari kolom `role`).
  final String role;
  final String fullName;
  final String? email;
  final String phone;
  final String? avatarUrl;

  /// ID titik ambil (lihat `PickupPoint`) yang ditandai favorit oleh pengguna; null bila belum ada.
  final int? favoritePickupPointId;

  const ApiUser({
    required this.id,
    required this.role,
    required this.fullName,
    this.email,
    required this.phone,
    this.avatarUrl,
    this.favoritePickupPointId,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'] as int,
        role: json['role'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String,
        avatarUrl: json['avatar_url'] as String?,
        favoritePickupPointId: json['favorite_pickup_point_id'] as int?,
      );
}
