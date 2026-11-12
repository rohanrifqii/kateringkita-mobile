import '../api/api_client.dart';
import '../models/product_model.dart';
import 'catalog_repository.dart';

/// Menu favorit pembeli lewat REST backend (butuh sesi pembeli).
class FavoriteRepository {
  FavoriteRepository(this._api);

  final ApiClient _api;

  /// Kartu menu yang sama dengan katalog, terbaru disimpan lebih dulu.
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

  /// Idempoten di server (204).
  Future<void> add(int menuId) => _api.put('/me/favorites/$menuId');

  /// Idempoten di server (204), juga bila belum pernah difavoritkan.
  Future<void> remove(int menuId) => _api.delete('/me/favorites/$menuId');
}
