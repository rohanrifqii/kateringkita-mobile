import '../api/api_client.dart';
import '../models/category_model.dart';
import '../models/pickup_point.dart';
import '../models/product_model.dart';
import '../models/voucher.dart';

class MenuPage {
  final List<ProductModel> items;
  final int total;
  final int page;
  const MenuPage({required this.items, required this.total, required this.page});
}

class MenuReview {
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

class MerchantProfile {
  final int id;
  final String slug;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String merchantTypeName;
  final bool isOpen;
  final String openTime;
  final String closeTime;
  final double ratingAvg;
  final int ratingCount;
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

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;
  List<CategoryModel>? _categories;
  List<PickupPoint>? _pickupPoints;

  Future<List<CategoryModel>> categories() async {
    final cached = _categories;
    if (cached != null) return cached;
    final res = await _api.get('/meta/categories');
    return _categories = (res.data as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PickupPoint>> pickupPoints() async {
    final cached = _pickupPoints;
    if (cached != null) return cached;
    final res = await _api.get('/meta/pickup-points');
    return _pickupPoints = (res.data as List)
        .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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

  Future<MerchantProfile> merchant(String slug) async {
    final res = await _api.get('/merchants/$slug');
    return MerchantProfile.fromJson(res.data as Map<String, dynamic>);
  }
}
