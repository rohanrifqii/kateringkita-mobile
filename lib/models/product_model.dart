class ProductModel {
  final String id;
  final String name;
  final double price;
  final double rating;
  final int reviewCount;
  final String image;
  final String? badgeText;
  final String badgeType; // 'quota', 'available'
  final String vendor;
  final String description;
  final List<String> options;
  final bool isLiked;
  final String category; // 'danusan', 'manis', 'katering', 'snack'

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.image,
    this.badgeText,
    this.badgeType = 'available',
    required this.vendor,
    required this.description,
    this.options = const [],
    this.isLiked = false,
    this.category = 'danusan',
  });

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    double? rating,
    int? reviewCount,
    String? image,
    String? badgeText,
    String badgeType = 'available',
    String? vendor,
    String? description,
    List<String>? options,
    bool? isLiked,
    String? category,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      image: image ?? this.image,
      badgeText: badgeText ?? this.badgeText,
      badgeType: badgeType,
      vendor: vendor ?? this.vendor,
      description: description ?? this.description,
      options: options ?? this.options,
      isLiked: isLiked ?? this.isLiked,
      category: category ?? this.category,
    );
  }
}

class ProductData {
  static const ProductModel defaultProduct = ProductModel(
    id: 'prod-001',
    name: 'Lumpia Diego',
    price: 25000,
    rating: 4.6,
    reviewCount: 120,
    image: 'assets/images/lumpia_diego.png',
    badgeText: '🔥 Sisa 8 Porsi',
    badgeType: 'quota',
    vendor: 'Diego Katering',
    description:
        'Lumpia goreng super renyah khas Diego Katering, isian rebung manis, telur orak-arik, dan daging ayam gurih dengan saus tauco bawang spesial.',
    options: ['Sambal Pisah', 'Ekstra Cabai Rawit', 'Goreng Hangat'],
    isLiked: true,
    category: 'danusan',
  );

  static final List<ProductModel> mockProducts = [
    defaultProduct,
    const ProductModel(
      id: 'prod-002',
      name: 'Martabak Manis',
      price: 35000,
      rating: 4.8,
      reviewCount: 85,
      image: 'assets/images/martabak.png',
      badgeText: 'Tersedia',
      badgeType: 'available',
      vendor: 'Martabak Pecenongan',
      description: 'Martabak manis tebal empuk dengan aneka topping keju, coklat, dan kacang gurih.',
      options: ['Keju Spesial', 'Coklat Leleh', 'Kacang'],
      isLiked: true,
      category: 'manis',
    ),
    const ProductModel(
      id: 'prod-003',
      name: 'Nasi Kuning Slamet',
      price: 20000,
      rating: 4.9,
      reviewCount: 210,
      image: 'assets/images/nasi_kuning.png',
      badgeText: '🔥 Sisa 5 Porsi',
      badgeType: 'quota',
      vendor: 'Dapur Slamet',
      description: 'Nasi kuning wangi rempah dengan suwiran ayam, sambal balado tempe orek, dan telur iris.',
      options: ['Sambal Tambah', 'Telur Utuh'],
      isLiked: false,
      category: 'katering',
    ),
    const ProductModel(
      id: 'prod-004',
      name: 'Donat Surgawi',
      price: 15000,
      rating: 4.7,
      reviewCount: 95,
      image: 'assets/images/donat_surgawi.png',
      badgeText: 'Tersedia',
      badgeType: 'available',
      vendor: 'Surgawi Bakery',
      description: 'Donat kentang empuk bertabur gula salju dan glaze rasa premium.',
      options: ['Glaze Cokelat', 'Gula Halus'],
      isLiked: true,
      category: 'manis',
    ),
    const ProductModel(
      id: 'prod-005',
      name: 'Risoles Bu Tima',
      price: 18000,
      rating: 4.8,
      reviewCount: 110,
      image: 'assets/images/risoles.png',
      badgeText: 'Tersedia',
      badgeType: 'available',
      vendor: 'Dapur Bu Tima',
      description: 'Risoles mayo lumer isi daging asap, telur rebus, dan saus mayo creamy gurih.',
      options: ['Cabe Rawit Segar', 'Saus Keju'],
      isLiked: true,
      category: 'danusan',
    ),
  ];

  static ProductModel getProductByName(String name) {
    try {
      return mockProducts.firstWhere(
        (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase(),
      );
    } catch (_) {
      return defaultProduct;
    }
  }
}
