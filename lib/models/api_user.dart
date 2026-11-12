class ApiUser {
  final int id;
  final String role;
  final String fullName;
  final String? email;
  final String phone;
  final String? avatarUrl;
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
