// Penggabung ulasan untuk tab Penilaian di profil toko: mengambil ulasan beberapa menu toko lewat
// CatalogRepository (GET /menus/{id}/reviews) karena backend belum punya endpoint ulasan per toko.
import '../models/product_model.dart';
import 'catalog_repository.dart';

/// Ulasan satu menu beserta nama menunya (untuk tab Penilaian toko).
class StoreReview {
  final MenuReview review;
  final int menuId;
  final String menuName;

  const StoreReview({
    required this.review,
    required this.menuId,
    required this.menuName,
  });
}

/// Hasil gabungan; [failed] = jumlah menu yang ulasannya gagal dimuat.
class StoreReviews {
  final List<StoreReview> reviews;
  final int failed;

  const StoreReviews({required this.reviews, this.failed = 0});
}

/// Menu yang punya ulasan, terbanyak ulasan dulu, paling banyak [max].
List<ProductModel> pickReviewedMenus(List<ProductModel> menus,
    {int max = 10}) {
  final list = menus.where((m) => m.ratingCount > 0).toList()
    ..sort((a, b) {
      final c = b.ratingCount.compareTo(a.ratingCount);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return list.take(max).toList();
}

/// Backend tidak punya endpoint ulasan per toko: ambil
/// `GET /menus/:id/reviews?page=1&limit=[perMenu]` untuk [maxMenus] menu
/// berulasan terbanyak (paralel), gabungkan, urutkan terbaru dulu.
/// Galat dilempar hanya bila semua permintaan gagal.
Future<StoreReviews> loadStoreReviews(
  CatalogRepository repo,
  List<ProductModel> menus, {
  int maxMenus = 10,
  int perMenu = 5,
}) async {
  final picked = pickReviewedMenus(menus, max: maxMenus);
  if (picked.isEmpty) return const StoreReviews(reviews: []);

  Object? firstError;
  var failed = 0;
  final results = await Future.wait(picked.map((m) async {
    try {
      return await repo.reviews(m.id, limit: perMenu);
    } catch (e) {
      firstError ??= e;
      failed++;
      return const <MenuReview>[];
    }
  }));
  if (failed == picked.length) throw firstError!;

  final merged = <StoreReview>[
    for (var i = 0; i < picked.length; i++)
      for (final r in results[i])
        StoreReview(review: r, menuId: picked[i].id, menuName: picked[i].name),
  ]..sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
  return StoreReviews(reviews: merged, failed: failed);
}
