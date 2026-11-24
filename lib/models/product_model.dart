import 'category_model.dart';
import 'pickup_point.dart';

class MenuOption {
  final int id;
  final String name;
  final int extraPrice;

  const MenuOption({
    required this.id,
    required this.name,
    this.extraPrice = 0,
  });

  factory MenuOption.fromJson(Map<String, dynamic> json) => MenuOption(
        id: json['id'] as int,
        name: json['name'] as String,
        extraPrice: (json['extra_price'] as num?)?.toInt() ?? 0,
      );
}

class MerchantRef {
  final int id;
  final String slug;
  final String businessName;
  final bool isOpen;
  final String? logoUrl;
  final String? openTime;
  final String? closeTime;
  final List<PickupPoint> pickupPoints;

  const MerchantRef({
    required this.id,
    required this.slug,
    required this.businessName,
    required this.isOpen,
    this.logoUrl,
    this.openTime,
    this.closeTime,
    this.pickupPoints = const [],
  });

  factory MerchantRef.fromJson(Map<String, dynamic> json) => MerchantRef(
        id: json['id'] as int,
        slug: json['slug'] as String,
        businessName: json['business_name'] as String,
        isOpen: json['is_open'] as bool,
        logoUrl: json['logo_url'] as String?,
        openTime: json['open_time'] as String?,
        closeTime: json['close_time'] as String?,
        pickupPoints: ((json['pickup_points'] as List?) ?? const [])
            .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProductModel {
  final int id;
  final String name;
  final int price;
  final String unitLabel;
  final String? imageUrl;

  /// Foto tambahan (maks 4) selain [imageUrl]; hanya dari detail menu.
  final List<String> gallery;
  final CategoryModel? category;
  final MerchantRef merchant;
  final int available;
  final String badge; // sold_out | preorder | low_stock | available
  final double ratingAvg;
  final int ratingCount;
  final bool isFavorite;
  final String? description;
  final List<MenuOption> options;
  final int minOrderQty;
  final int prepMinutes;
  final bool isPreorder;
  final int preorderDays;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.unitLabel = 'porsi',
    this.imageUrl,
    this.gallery = const [],
    this.category,
    required this.merchant,
    this.available = 0,
    this.badge = 'available',
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isFavorite = false,
    this.description,
    this.options = const [],
    this.minOrderQty = 1,
    this.prepMinutes = 0,
    this.isPreorder = false,
    this.preorderDays = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as int,
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
        unitLabel: (json['unit_label'] as String?) ?? 'porsi',
        imageUrl: json['image_url'] as String?,
        gallery: ((json['gallery'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        category: json['category'] == null
            ? null
            : CategoryModel.fromJson(json['category'] as Map<String, dynamic>),
        merchant:
            MerchantRef.fromJson(json['merchant'] as Map<String, dynamic>),
        available: (json['available'] as num?)?.toInt() ?? 0,
        badge: (json['badge'] as String?) ?? 'available',
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        isFavorite: (json['is_favorite'] as bool?) ?? false,
        description: json['description'] as String?,
        options: ((json['options'] as List?) ?? const [])
            .map((e) => MenuOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        minOrderQty: (json['min_order_qty'] as num?)?.toInt() ?? 1,
        prepMinutes: (json['prep_minutes'] as num?)?.toInt() ?? 0,
        // Kartu katalog tidak memuat is_preorder; badge 'preorder' jadi penanda (detail menu memuatnya eksplisit)
        isPreorder:
            (json['is_preorder'] as bool?) ?? json['badge'] == 'preorder',
        preorderDays: (json['preorder_days'] as num?)?.toInt() ?? 0,
      );

  /// Foto utama lalu foto tambahan, untuk galeri geser di detail menu.
  List<String> get photos => [?imageUrl, ...gallery];

  // Getter kompatibilitas untuk layar lama.
  double get rating => ratingAvg;
  int get reviewCount => ratingCount;
  String get vendor => merchant.businessName;
  bool get isLiked => isFavorite;
  bool get canOrder => merchant.isOpen && badge != 'sold_out';

  String? get badgeText {
    switch (badge) {
      case 'sold_out':
        return 'Habis';
      case 'preorder':
        return preorderDays > 0 ? 'Pre-order H-$preorderDays' : 'Pre-order';
      case 'low_stock':
        return '🔥 Sisa $available Porsi';
      case 'available':
        return 'Tersedia';
    }
    return null;
  }

  String get badgeType =>
      (badge == 'low_stock' || badge == 'sold_out') ? 'quota' : 'available';

  ProductModel copyWith({bool? isFavorite}) => ProductModel(
        id: id,
        name: name,
        price: price,
        unitLabel: unitLabel,
        imageUrl: imageUrl,
        gallery: gallery,
        category: category,
        merchant: merchant,
        available: available,
        badge: badge,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
        isFavorite: isFavorite ?? this.isFavorite,
        description: description,
        options: options,
        minOrderQty: minOrderQty,
        prepMinutes: prepMinutes,
        isPreorder: isPreorder,
        preorderDays: preorderDays,
      );
}
