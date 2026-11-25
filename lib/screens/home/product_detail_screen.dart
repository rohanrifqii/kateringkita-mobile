// Layar Detail Produk (rute AppRoutes.productDetail), dibuka saat kartu menu diketuk; argumen rute = ProductModel.
// Detail menu, ulasan, dan profil toko dimuat lewat CatalogRepository dari backend REST KateringKita;
// status favorit (ikon hati) disimpan ke server lewat FavoriteButton -> FavoritesProvider (PUT/DELETE /me/favorites/{id}).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../models/product_model.dart';
import '../../data/catalog_repository.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/cart_button.dart';

/// Layar detail satu menu: galeri, harga, opsi, info toko, ulasan, dan tombol tambah ke keranjang.
class ProductDetailScreen extends StatefulWidget {
  /// Produk cadangan bila argumen rute bukan ProductModel.
  final ProductModel? product;

  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

/// State detail menu: produk yang ditampilkan, opsi terpilih, profil toko, dan ulasan.
class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductModel _product;
  // true bila tidak ada produk sama sekali; layar langsung ditutup (pop) setelah frame pertama.
  bool _missing = false;
  bool _initialized = false;
  MenuOption? _selectedOption; // null = tanpa opsi
  MerchantProfile? _merchant;
  List<MenuReview> _reviews = const [];
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  // Galeri saat ini hanya berisi satu gambar utama produk.
  List<String?> get _galleryImages => [_product.imageUrl];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hanya sekali: ambil produk dari argumen rute, kalau tidak ada dari widget.product.
    if (_initialized) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ProductModel) {
      _product = args;
    } else {
      final p = widget.product;
      if (p == null) {
        _missing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        return;
      }
      _product = p;
    }
    _initialized = true;
    _load();
  }

  /// Memuat detail menu (GET /menus/{id}), ulasan (GET /menus/{id}/reviews), dan profil toko
  /// (GET /merchants/{slug}) secara berurutan. Tiap permintaan
  /// berdiri sendiri: bila gagal, galatnya diabaikan dan layar tetap memakai data yang sudah ada.
  Future<void> _load() async {
    final repo = context.read<CatalogRepository>();
    final card = _product;
    try {
      final detail = await repo.menuDetail(card.id);
      if (!mounted) return;
      setState(() => _product = detail);
    } catch (_) {
      // Tetap menampilkan data kartu bila detail gagal dimuat.
    }
    try {
      final reviews = await repo.reviews(card.id);
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (_) {}
    try {
      final merchant = await repo.merchant(card.merchant.slug);
      if (!mounted) return;
      setState(() => _merchant = merchant);
    } catch (_) {}
  }

  /// Teks tombol bawah: "Toko sedang tutup", "Habis" (badge sold_out), atau "Tambah ke Keranjang".
  String get _buttonText {
    if (!_product.merchant.isOpen) return 'Toko sedang tutup';
    if (_product.badge == 'sold_out') return 'Habis';
    return 'Tambah ke Keranjang';
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) return const Scaffold();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Image Carousel
                Stack(
                  children: [
                    SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _imagePageController,
                        itemCount: _galleryImages.length,
                        onPageChanged: (index) {
                          setState(() => _currentImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return MenuImage(
                            _galleryImages[index],
                            width: double.infinity,
                            height: 340,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    // Carousel Indicators
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_galleryImages.length, (index) {
                          final isSelected = _currentImageIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isSelected ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),

                // Sheet Content
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _product.name,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Price
                        Text(
                          '${AppCurrency.format(_product.price)} / ${_product.unitLabel}',
                          style: AppTextStyles.price.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Rating & Danus UB Tag
                        Row(
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  Icons.star_rounded,
                                  color: i < _product.rating.round()
                                      ? AppColors.warning
                                      : AppColors.cardBorder,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_product.rating} (${_product.reviewCount} ulasan)',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Status Card (toko tutup / stok)
                        if (!_product.merchant.isOpen ||
                            (_product.badgeText != null &&
                                _product.badge != 'available')) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              !_product.merchant.isOpen
                                  ? 'Toko sedang tutup'
                                  : _product.badgeText!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Store / Dapur Profile Card (Clickable -> StoreProfileScreen)
                        Builder(
                          builder: (context) {
                            final m = _product.merchant;
                            final mp = _merchant;
                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.storeProfile,
                                  arguments: _product.merchant.slug,
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: MenuImage(
                                        m.logoUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.verified_rounded,
                                                color: AppColors.primary,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  m.businessName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles.h4
                                                      .copyWith(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                color: AppColors.warning,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  [
                                                    if (mp != null)
                                                      '${mp.ratingAvg} (${mp.ratingCount})',
                                                    if (m.openTime != null && m.closeTime != null)
                                                      '${m.openTime}–${m.closeTime} WIB',
                                                  ].join(' • '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Kunjungi Dapur',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Description
                        Text(
                          'Description',
                          style: AppTextStyles.h3.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _product.description ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Option Pills
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: _product.options.map((option) {
                            final isSelected =
                                _selectedOption?.id == option.id;
                            final label = option.extraPrice > 0
                                ? '${option.name} (+ ${AppCurrency.format(option.extraPrice)})'
                                : option.name;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedOption =
                                      isSelected ? null : option;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryBackground
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  isSelected ? '✓ $label' : label,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Ulasan
                        if (_reviews.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Ulasan',
                            style: AppTextStyles.h3.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          for (final r in _reviews)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r.customerName,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.star_rounded,
                                        color: AppColors.warning,
                                        size: 14,
                                      ),
                                      Text(
                                        '${r.rating}',
                                        style: AppTextStyles.bodySmall
                                            .copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (r.comment != null &&
                                      r.comment!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        r.comment!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Floating Navigation Bar (Back, keranjang, & Favorite)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  // Ikon keranjang dengan lencana jumlah item; diketuk membuka Checkout.
                  const CartButton(),
                  const SizedBox(width: 8),
                  // Favorite Button: simpan/hapus menu favorit di server; tamu diminta masuk dulu.
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: FavoriteButton(menu: _product),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Fixed Button: menambah _product beserta opsi terpilih ke keranjang lewat
          // addToCartWithPrompt (bila keranjang berisi menu toko lain, pengguna ditanya dulu apakah
          // keranjang diganti). Nonaktif bila _product.canOrder false.
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: PrimaryButton(
              text: _buttonText,
              gradient: _product.canOrder ? AppColors.primaryGradient : null,
              backgroundColor: AppColors.textMuted,
              onPressed: !_product.canOrder
                  ? null
                  : () => addToCartWithPrompt(context, _product,
                      option: _selectedOption),
            ),
          ),
        ],
      ),
    );
  }
}
