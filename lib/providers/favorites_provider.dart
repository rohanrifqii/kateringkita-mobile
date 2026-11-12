import 'package:flutter/foundation.dart';

import '../data/favorite_repository.dart';
import '../models/product_model.dart';

/// Status favorit menu selama sesi pembeli.
///
/// Sumber utamanya `is_favorite` di kartu/detail menu dari server. Aksi hati
/// di sesi ini disimpan sebagai override per id menu supaya semua layar
/// (kartu, detail, daftar Favorit) langsung sama. Perubahan bersifat
/// optimistis dan dikembalikan bila server menolak.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._repo);

  final FavoriteRepository _repo;
  final Map<int, bool> _overrides = {};
  final Set<int> _busy = {};

  /// Naik setiap kali favorit di server berubah atau status dikosongkan;
  /// layar Favorit memakainya untuk tahu kapan perlu memuat ulang.
  int _revision = 0;
  int get revision => _revision;

  /// Naik saat [clear]; jawaban permintaan dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  bool isFavorite(ProductModel menu) =>
      _overrides[menu.id] ?? menu.isFavorite;

  bool isBusy(int menuId) => _busy.contains(menuId);

  /// Simpan/hapus favorit. Ketukan saat permintaan menu yang sama masih
  /// berjalan diabaikan. Galat diteruskan setelah status dikembalikan.
  Future<void> setFavorite(ProductModel menu, bool value) async {
    final id = menu.id;
    if (_busy.contains(id)) return;
    final epoch = _epoch;
    final had = _overrides.containsKey(id);
    final before = _overrides[id];

    _busy.add(id);
    _overrides[id] = value;
    notifyListeners();
    try {
      if (value) {
        await _repo.add(id);
      } else {
        await _repo.remove(id);
      }
      if (epoch == _epoch) _revision++;
    } catch (_) {
      if (epoch == _epoch) {
        if (had) {
          _overrides[id] = before!;
        } else {
          _overrides.remove(id);
        }
      }
      rethrow;
    } finally {
      if (epoch == _epoch) {
        _busy.remove(id);
        notifyListeners();
      }
    }
  }

  /// Dipanggil saat keluar / sesi tidak valid: favorit milik akun sebelumnya
  /// tidak boleh terbawa.
  void clear() {
    _epoch++;
    _overrides.clear();
    _busy.clear();
    _revision++;
    notifyListeners();
  }
}
