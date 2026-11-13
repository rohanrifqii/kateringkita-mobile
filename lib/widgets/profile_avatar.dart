import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Foto profil dari server (`avatar_url`); inisial nama bila kosong, sedang
/// dimuat, atau gagal dimuat. [borderRadius] null berarti lingkaran.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.url,
    required this.size,
    this.borderRadius,
  });

  final String name;
  final String? url;
  final double size;
  final BorderRadius? borderRadius;

  Widget _initials() {
    final n = name.trim();
    return Container(
      key: const ValueKey('profile-avatar-initials'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        n.isNotEmpty ? n[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: size * 0.37,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _initials();
    final image = Image.network(
      u,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initials(),
      loadingBuilder: (_, w, progress) => progress == null ? w : _initials(),
    );
    return borderRadius == null
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
