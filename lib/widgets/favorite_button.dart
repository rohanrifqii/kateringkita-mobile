// Tombol hati favorit dan fungsi simpan/hapus favorit menu atau toko, dipakai kartu menu, detail menu,
// dan profil toko. Alur: widget → FavoritesProvider → FavoriteRepository → backend.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/app_colors.dart';
import '../core/require_login.dart';
import '../data/catalog_repository.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Simpan / hapus [menu] dari favorit.
///
/// Tamu diarahkan ke Login lebih dulu; bila login berhasil menu langsung
/// disimpan. Perubahan optimistis lewat [FavoritesProvider] dan dikembalikan
/// bila server menolak.
Future<void> toggleFavorite(BuildContext context, ProductModel menu) {
  final favorites = context.read<FavoritesProvider>();
  return _toggle(
    context,
    busy: favorites.isBusy(menu.id),
    current: () => favorites.isFavorite(menu),
    save: (v) => favorites.setFavorite(menu, v),
    guestText: 'Masuk dulu untuk menyimpan menu favorit.',
    doneText: (v) => v
        ? 'Ditambahkan ke favorit: ${menu.name}'
        : 'Dihapus dari favorit: ${menu.name}',
  );
}

/// Simpan / hapus toko dari "Dapur Favorit"; aturan sama dengan
/// [toggleFavorite].
Future<void> toggleFavoriteMerchant(
    BuildContext context, MerchantProfile merchant) {
  final favorites = context.read<FavoritesProvider>();
  return _toggle(
    context,
    busy: favorites.isMerchantBusy(merchant.id),
    current: () => favorites.isFavoriteMerchant(merchant),
    save: (v) => favorites.setFavoriteMerchant(merchant, v),
    guestText: 'Masuk dulu untuk menyimpan Dapur Favorit.',
    doneText: (v) => v
        ? '${merchant.businessName} disimpan ke Dapur Favorit'
        : '${merchant.businessName} dihapus dari Dapur Favorit',
  );
}

/// Logika bersama [toggleFavorite] dan [toggleFavoriteMerchant]: abaikan bila
/// [busy], minta login untuk tamu, panggil [save], lalu tampilkan SnackBar.
Future<void> _toggle(
  BuildContext context, {
  required bool busy,
  required bool Function() current,
  required Future<void> Function(bool value) save,
  required String guestText,
  required String Function(bool value) doneText,
}) async {
  if (busy) return;
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
      ));
  }

  final bool value;
  // Tamu diminta login dulu; setelah berhasil, menu/toko selalu disimpan (bukan dibalik).
  if (context.read<AuthProvider>().isLoggedIn) {
    value = !current();
  } else {
    snack(guestText);
    if (!await requireLogin(context)) return;
    value = true;
  }

  try {
    await save(value);
  } on ApiException catch (e) {
    snack(e.message);
    return;
  } catch (_) {
    snack('Favorit gagal diperbarui. Coba lagi.');
    return;
  }
  snack(doneText(value));
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

  /// Menu yang status favoritnya ditampilkan.
  final ProductModel menu;

  /// Ukuran ikon hati.
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
