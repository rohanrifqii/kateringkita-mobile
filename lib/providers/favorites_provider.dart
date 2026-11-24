import 'package:flutter/foundation.dart';

import '../data/catalog_repository.dart';
import '../data/favorite_repository.dart';
import '../models/product_model.dart';

/// Status favorit menu & toko ("Dapur Favorit") selama sesi pembeli.
///
/// Sumber utamanya `is_favorite` dari server (kartu/detail menu, profil
/// toko). Aksi hati di sesi ini disimpan sebagai override per id supaya semua
/// layar langsung sama. Perubahan bersifat optimistis dan dikembalikan bila
/// server menolak.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._repo);

  final FavoriteRepository _repo;
  final Map<int, bool> _menus = {};
  final Set<int> _menuBusy = {};
  final Map<int, bool> _merchants = {};
  final Set<int> _merchantBusy = {};

  /// Naik setiap kali favorit menu di server berubah atau status dikosongkan;
  /// layar Favorit memakainya untuk tahu kapan perlu memuat ulang.
  int _revision = 0;
  int get revision => _revision;

  /// Padanan [revision] untuk toko favorit.
  int _merchantRevision = 0;
  int get merchantRevision => _merchantRevision;

  /// Naik saat [clear]; jawaban permintaan dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  bool isFavorite(ProductModel menu) => _menus[menu.id] ?? menu.isFavorite;

  bool isBusy(int menuId) => _menuBusy.contains(menuId);

  bool isFavoriteMerchant(MerchantProfile merchant) =>
      _merchants[merchant.id] ?? merchant.isFavorite;

  bool isMerchantBusy(int merchantId) => _merchantBusy.contains(merchantId);

  /// Simpan/hapus menu favorit. Ketukan saat permintaan menu yang sama masih
  /// berjalan diabaikan. Galat diteruskan setelah status dikembalikan.
  Future<void> setFavorite(ProductModel menu, bool value) => _set(
        _menus,
        _menuBusy,
        menu.id,
        value,
        () => value ? _repo.add(menu.id) : _repo.remove(menu.id),
        () => _revision++,
      );

  /// Simpan/hapus toko favorit, aturan sama dengan [setFavorite].
  Future<void> setFavoriteMerchant(MerchantProfile merchant, bool value) =>
      _set(
        _merchants,
        _merchantBusy,
        merchant.id,
        value,
        () => value
            ? _repo.addMerchant(merchant.id)
            : _repo.removeMerchant(merchant.id),
        () => _merchantRevision++,
      );

  Future<void> _set(
    Map<int, bool> overrides,
    Set<int> busy,
    int id,
    bool value,
    Future<void> Function() call,
    void Function() onSaved,
  ) async {
    if (busy.contains(id)) return;
    final epoch = _epoch;
    final had = overrides.containsKey(id);
    final before = overrides[id];

    busy.add(id);
    overrides[id] = value;
    notifyListeners();
    try {
      await call();
      if (epoch == _epoch) onSaved();
    } catch (_) {
      if (epoch == _epoch) {
        if (had) {
          overrides[id] = before!;
        } else {
          overrides.remove(id);
        }
      }
      rethrow;
    } finally {
      if (epoch == _epoch) {
        busy.remove(id);
        notifyListeners();
      }
    }
  }

  /// Dipanggil saat keluar / sesi tidak valid: favorit milik akun sebelumnya
  /// tidak boleh terbawa.
  void clear() {
    _epoch++;
    _menus.clear();
    _menuBusy.clear();
    _merchants.clear();
    _merchantBusy.clear();
    _revision++;
    _merchantRevision++;
    notifyListeners();
  }
}
