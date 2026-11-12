import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/app_colors.dart';
import '../core/require_login.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Simpan / hapus [menu] dari favorit.
///
/// Tamu diarahkan ke Login lebih dulu; bila login berhasil menu langsung
/// disimpan. Perubahan optimistis lewat [FavoritesProvider] dan dikembalikan
/// bila server menolak.
Future<void> toggleFavorite(BuildContext context, ProductModel menu) async {
  final messenger = ScaffoldMessenger.of(context);
  final favorites = context.read<FavoritesProvider>();
  if (favorites.isBusy(menu.id)) return;
  void snack(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
      ));
  }

  final bool value;
  if (context.read<AuthProvider>().isLoggedIn) {
    value = !favorites.isFavorite(menu);
  } else {
    snack('Masuk dulu untuk menyimpan menu favorit.');
    if (!await requireLogin(context)) return;
    value = true;
  }

  try {
    await favorites.setFavorite(menu, value);
  } on ApiException catch (e) {
    snack(e.message);
    return;
  } catch (_) {
    snack('Favorit gagal diperbarui. Coba lagi.');
    return;
  }
  snack(value
      ? 'Ditambahkan ke favorit: ${menu.name}'
      : 'Dihapus dari favorit: ${menu.name}');
}

/// Ikon hati untuk kartu/detail menu. Status dari server (`is_favorite`)
/// plus aksi di sesi ini; tamu selalu melihat hati kosong.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.menu,
    this.size = 20,
    this.color,
    this.compact = false,
  });

  final ProductModel menu;
  final double size;

  /// Warna hati kosong; bawaan [AppColors.textPrimary].
  final Color? color;

  /// Tanpa padding/ukuran minimum IconButton (untuk kartu kecil).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    final on = loggedIn && context.watch<FavoritesProvider>().isFavorite(menu);
    return IconButton(
      tooltip: on ? 'Hapus dari favorit' : 'Simpan ke favorit',
      padding: compact ? EdgeInsets.zero : null,
      constraints: compact ? const BoxConstraints() : null,
      visualDensity: compact ? VisualDensity.compact : null,
      icon: Icon(
        on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: size,
        color: on ? AppColors.danger : (color ?? AppColors.textPrimary),
      ),
      onPressed: () => toggleFavorite(context, menu),
    );
  }
}
