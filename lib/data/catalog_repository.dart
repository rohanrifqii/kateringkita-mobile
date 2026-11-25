// Repository katalog: satu-satunya pintu layar untuk membaca menu, kategori, titik ambil, ulasan,
// dan profil toko dari backend. Alur: layar → provider (CatalogRepository disediakan di main.dart)
// → CatalogRepository → ApiClient → backend REST KateringKita. Juga berisi model kecil hasilnya.
import '../api/api_client.dart';
import '../models/category_model.dart';
import '../models/pickup_point.dart';
import '../models/product_model.dart';
import '../models/voucher.dart';

/// Satu halaman hasil daftar menu dari [CatalogRepository.menus].
class MenuPage {
  /// Menu pada halaman ini.
  final List<ProductModel> items;

  /// Jumlah seluruh menu yang cocok dengan filter (dari `meta.total`), bukan hanya di halaman ini.
  final int total;

  /// Nomor halaman ini, mulai dari 1.
  final int page;
  const MenuPage({required this.items, required this.total, required this.page});
}

/// Satu ulasan pembeli untuk sebuah menu (dari GET /menus/{id}/reviews).
/// [fromJson] mengubah satu objek JSON ulasan menjadi kelas ini.
class MenuReview {
  /// Nilai bintang yang diberikan pembeli.
  final int rating;
  final String? comment;
  final String customerName;
  final DateTime createdAt;

  const MenuReview({
    required this.rating,
    this.comment,
    required this.customerName,
    required this.createdAt,
  });

  factory MenuReview.fromJson(Map<String, dynamic> json) => MenuReview(
        rating: (json['rating'] as num).toInt(),
        comment: json['comment'] as String?,
        customerName: json['customer_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Profil lengkap sebuah toko/penjual (merchant), dari GET /merchants/{slug}.
///
/// Berbeda dengan `MerchantRef` di `product_model.dart` yang hanya ringkasan toko
/// di dalam data menu. [fromJson] mengubah objek JSON profil toko menjadi kelas ini.
class MerchantProfile {
  final int id;
  /// Pengenal toko berbentuk teks yang dipakai di alamat GET /merchants/{slug}.
  final String slug;
  final String businessName;
  final String? description;
  final String? logoUrl;

  /// URL foto sampul (background) profil toko dari kolom `cover_url`: foto lanskap yang diunggah penjual.
  /// Null bila penjual belum memasangnya; layar profil toko lalu memakai warna utama polos.
  final String? coverUrl;

  /// Nama jenis toko, diambil dari `merchant_type.name` pada JSON.
  final String merchantTypeName;

  /// Status buka toko menurut backend saat data diambil.
  final bool isOpen;

  /// Jam buka dan tutup dalam bentuk teks persis seperti dikirim backend.
  final String openTime;
  final String closeTime;

  /// Rata-rata bintang ulasan dan jumlah ulasan; 0 bila backend tidak mengirimnya.
  final double ratingAvg;
  final int ratingCount;

  /// Titik ambil pesanan yang dilayani toko ini.
  final List<PickupPoint> pickupPoints;

  /// Toko favorit pembeli ("Dapur Favorit"); false untuk tamu, peran lain,
  /// dan server yang belum memuat kolom ini.
  final bool isFavorite;

  /// Voucher toko publik yang berlaku (hanya dari GET /merchants/:slug).
  final List<Voucher> vouchers;

  const MerchantProfile({
    required this.id,
    required this.slug,
    required this.businessName,
    this.description,
    this.logoUrl,
    this.coverUrl,
    required this.merchantTypeName,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
    required this.ratingAvg,
    required this.ratingCount,
    this.pickupPoints = const [],
    this.isFavorite = false,
    this.vouchers = const [],
  });

  factory MerchantProfile.fromJson(Map<String, dynamic> json) =>
      MerchantProfile(
        id: json['id'] as int,
        slug: json['slug'] as String,
        businessName: json['business_name'] as String,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        coverUrl: json['cover_url'] as String?,
        merchantTypeName:
            (json['merchant_type'] as Map<String, dynamic>)['name'] as String,
        isOpen: json['is_open'] as bool,
        openTime: json['open_time'] as String,
        closeTime: json['close_time'] as String,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        pickupPoints: ((json['pickup_points'] as List?) ?? const [])
            .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        isFavorite: (json['is_favorite'] as bool?) ?? false,
        vouchers: ((json['vouchers'] as List?) ?? const [])
            .map((e) => Voucher.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Pengambil data katalog dari backend memakai [ApiClient] yang diberikan lewat konstruktor.
///
/// Semua metode melempar `ApiException` (dari ApiClient) bila permintaan gagal.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;
  // Cache di memori: kategori dan titik ambil jarang berubah, jadi cukup diambil sekali
  // selama objek repository ini hidup.
  List<CategoryModel>? _categories;
  List<PickupPoint>? _pickupPoints;

  /// Mengambil semua kategori menu dari GET /meta/categories.
  ///
  /// Hasil panggilan pertama disimpan; panggilan berikutnya langsung mengembalikan
  /// daftar yang tersimpan itu tanpa menghubungi backend.
  Future<List<CategoryModel>> categories() async {
    final cached = _categories;
    if (cached != null) return cached;
    final res = await _api.get('/meta/categories');
    return _categories = (res.data as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil semua titik ambil pesanan dari GET /meta/pickup-points.
  ///
  /// Sama seperti [categories], hasilnya disimpan setelah panggilan pertama.
  Future<List<PickupPoint>> pickupPoints() async {
    final cached = _pickupPoints;
    if (cached != null) return cached;
    final res = await _api.get('/meta/pickup-points');
    return _pickupPoints = (res.data as List)
        .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil satu halaman daftar menu dari GET /menus.
  ///
  /// - [q]: kata kunci pencarian; tidak dikirim bila null atau kosong.
  /// - [category]: slug kategori untuk menyaring hasil; tidak dikirim bila null.
  /// - [merchant]: slug toko untuk menyaring hasil; tidak dikirim bila null.
  /// - [sort]: urutan hasil, bawaan `'popular'`.
  /// - [page] dan [limit]: nomor halaman (mulai 1) dan jumlah menu per halaman.
  ///
  /// Mengembalikan [MenuPage]. Bila backend tidak mengirim `meta`, `total` diisi jumlah
  /// menu di halaman ini dan `page` diisi nilai [page] yang diminta.
  Future<MenuPage> menus({
    String? q,
    String? category,
    String? merchant,
    String sort = 'popular',
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get('/menus', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      // Tanda `?` di depan nilai: pasangan ini hanya dimasukkan bila nilainya tidak null.
      'category': ?category,
      'merchant': ?merchant,
      'sort': sort,
      'page': '$page',
      'limit': '$limit',
    });
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

  /// Mengambil detail lengkap satu menu (termasuk deskripsi dan pilihan tambahan)
  /// dari GET /menus/{id}.
  Future<ProductModel> menuDetail(int id) async {
    final res = await _api.get('/menus/$id');
    return ProductModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Ulasan terbaru dulu. [limit] bawaan server 20, maks 100.
  Future<List<MenuReview>> reviews(int menuId,
      {int page = 1, int? limit}) async {
    final res = await _api.get('/menus/$menuId/reviews', query: {
      'page': '$page',
      if (limit != null) 'limit': '$limit',
    });
    return (res.data as List)
        .map((e) => MenuReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil profil toko dengan [slug] tertentu dari GET /merchants/{slug}.
  Future<MerchantProfile> merchant(String slug) async {
    final res = await _api.get('/merchants/$slug');
    return MerchantProfile.fromJson(res.data as Map<String, dynamic>);
  }
}
