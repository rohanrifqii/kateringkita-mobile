// Repository favorit: daftar, simpan, dan hapus menu favorit serta toko favorit ("Dapur Favorit").
// Alur: FavoritesProvider / layar Favorit → FavoriteRepository → ApiClient → backend (/me/favorites...).
import '../api/api_client.dart';
import '../models/product_model.dart';
import 'catalog_repository.dart';

/// Satu halaman toko favorit dari [FavoriteRepository.listMerchants]:
/// [items] di halaman ini, [total] seluruh toko favorit, [page] mulai 1.
class MerchantPage {
  final List<MerchantProfile> items;
  final int total;
  final int page;

  const MerchantPage({
    required this.items,
    required this.total,
    required this.page,
  });
}

/// Menu & toko favorit pembeli lewat REST backend (butuh sesi pembeli).
class FavoriteRepository {
  FavoriteRepository(this._api);

  final ApiClient _api;

  /// GET /me/favorites: satu halaman menu favorit. Kartu menu sama dengan
  /// katalog, yang terakhir disimpan tampil lebih dulu.
  /// Toko tutup & menu habis tetap ikut.
  Future<MenuPage> list({int page = 1, int limit = 20}) async {
    final res = await _api.get('/me/favorites',
        query: {'page': '$page', 'limit': '$limit'});
    final items = (res.data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = res.meta;
    return MenuPage(
      items: items,
      total: (meta?['total'] as num?)?.toInt() ?? items.length,
      page: (meta?['page'] as num?)?.toInt() ?? page,
    );
  }

  /// PUT /me/favorites/{menuId}: simpan menu ke favorit. Idempoten di server (204).
  Future<void> add(int menuId) => _api.put('/me/favorites/$menuId');

  /// DELETE /me/favorites/{menuId}: hapus menu dari favorit. Idempoten di
  /// server (204), juga bila belum pernah difavoritkan.
  Future<void> remove(int menuId) => _api.delete('/me/favorites/$menuId');

  /// GET /me/favorite-merchants: toko favorit ("Dapur Favorit"), kartu sama dengan GET /merchants/:slug,
  /// terbaru dulu; toko tutup tetap ikut.
  Future<MerchantPage> listMerchants({int page = 1, int limit = 20}) async {
    final res = await _api.get('/me/favorite-merchants',
        query: {'page': '$page', 'limit': '$limit'});
    final items = (res.data as List)
        .map((e) => MerchantProfile.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = res.meta;
    return MerchantPage(
      items: items,
      total: (meta?['total'] as num?)?.toInt() ?? items.length,
      page: (meta?['page'] as num?)?.toInt() ?? page,
    );
  }

  /// PUT /me/favorite-merchants/{merchantId}: simpan toko. Idempoten (204);
  /// toko tidak tampil → 404 "Toko tidak ditemukan.".
  Future<void> addMerchant(int merchantId) =>
      _api.put('/me/favorite-merchants/$merchantId');

  /// DELETE /me/favorite-merchants/{merchantId}: hapus toko. Idempoten (204).
  Future<void> removeMerchant(int merchantId) =>
      _api.delete('/me/favorite-merchants/$merchantId');
}
