// Model menu (ProductModel) beserta toko ringkas dan pilihan tambahannya, sebagaimana dikirim
// backend REST KateringKita (GET /menus dan GET /menus/{id}). Diambil lewat CatalogRepository,
// lalu ditampilkan layar katalog dan widget seperti FoodGridCard.
import 'category_model.dart';
import 'pickup_point.dart';

/// Pilihan tambahan untuk sebuah menu (misalnya tambah lauk) dan harga tambahannya.
/// [MenuOption.fromJson] mengubah objek JSON menjadi kelas ini.
class MenuOption {
  final int id;
  final String name;

  /// Tambahan harga dalam Rupiah bila pilihan ini diambil; 0 bila gratis.
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

/// Ringkasan toko yang ikut di dalam data menu, cukup untuk kartu menu dan tombol menuju
/// profil toko. Profil lengkap ada di `MerchantProfile` (catalog_repository.dart).
/// [MerchantRef.fromJson] mengubah objek JSON menjadi kelas ini.
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

/// Satu menu makanan dari backend.
///
/// Daftar menu (GET /menus) dan detail menu (GET /menus/{id}) sama-sama diubah ke kelas ini
/// lewat [ProductModel.fromJson]; kolom yang tidak dikirim backend diisi nilai bawaan.
class ProductModel {
  final int id;
  final String name;

  /// Harga per satuan dalam Rupiah.
  final int price;

  /// Nama satuan harga, bawaan `porsi`.
  final String unitLabel;
  final String? imageUrl;

  /// Foto tambahan (maks 4) selain [imageUrl]; hanya dari detail menu.
  final List<String> gallery;
  final CategoryModel? category;
  final MerchantRef merchant;

  /// Jumlah porsi yang masih bisa dipesan.
  final int available;
  final String badge; // sold_out | preorder | low_stock | available
  final double ratingAvg;
  final int ratingCount;

  /// True bila menu ini ada di favorit pengguna yang sedang login, menurut
  /// backend (`is_favorite`); status terbaru di aplikasi ada di FavoritesProvider.
  final bool isFavorite;
  final String? description;
  final List<MenuOption> options;

  /// Jumlah pesanan minimal, bawaan 1.
  final int minOrderQty;

  /// Lama persiapan dalam menit.
  final int prepMinutes;

  /// True bila menu harus dipesan beberapa hari sebelumnya; jumlah harinya di [preorderDays].
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
  /// Nama lama untuk [ratingAvg].
  double get rating => ratingAvg;

  /// Nama lama untuk [ratingCount].
  int get reviewCount => ratingCount;

  /// Nama toko penjual menu ini (nama lama dari `merchant.businessName`).
  String get vendor => merchant.businessName;

  /// Nama lama untuk [isFavorite].
  bool get isLiked => isFavorite;

  /// True bila menu boleh dipesan sekarang: toko sedang buka dan [badge] bukan `sold_out`.
  bool get canOrder => merchant.isOpen && badge != 'sold_out';

  /// Teks label kecil di atas gambar menu, diturunkan dari [badge]:
  /// `Habis`, `Pre-order` / `Pre-order H-<hari>`, `🔥 Sisa <n> Porsi`, atau `Tersedia`.
  /// Null bila nilai [badge] tidak dikenal.
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

  /// Kelompok label untuk menentukan warna: `'quota'` bila stok menipis atau habis,
  /// selain itu `'available'`.
  String get badgeType =>
      (badge == 'low_stock' || badge == 'sold_out') ? 'quota' : 'available';

  /// Membuat salinan menu ini dengan nilai [isFavorite] baru; kolom lain tetap sama.
  /// Bila [isFavorite] null, nilai lama dipertahankan.
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
