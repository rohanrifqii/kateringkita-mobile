import '../../api/api_exception.dart';
import '../../core/relative_time.dart';
import '../../data/catalog_repository.dart';
import '../../data/store_reviews.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/cart_button.dart';
import '../../providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../models/product_model.dart';
import '../../providers/theme_provider.dart';

class StoreProfileScreen extends StatefulWidget {
  final String? vendorName;

  const StoreProfileScreen({super.key, this.vendorName});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  String? _slug;
  MerchantProfile? _merchant;
  List<ProductModel> _menus = const [];
  bool _loading = true;
  bool _failed = false;
  bool _isStoreLiked = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _selectedTabIndex = 0; // 0: Menu, 1: Untukmu, 2: Penilaian, 3: Informasi
  String _selectedMenuCategory = 'Semua';

  // Tab Penilaian: dimuat saat tab pertama kali dibuka.
  StoreReviews? _reviews;
  bool _reviewsLoading = false;
  String? _reviewsError;
  int _reviewsSeq = 0;

  MerchantProfile get _vendor => _merchant!;

  void _selectTab(int index) {
    setState(() => _selectedTabIndex = index);
    if (index == 2 && _reviews == null && !_reviewsLoading) _loadReviews();
  }

  Future<void> _loadReviews() async {
    final repo = context.read<CatalogRepository>();
    final seq = ++_reviewsSeq;
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });
    try {
      final r = await loadStoreReviews(repo, _menus);
      if (!mounted || seq != _reviewsSeq) return;
      setState(() {
        _reviews = r;
        _reviewsLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reviewsSeq) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = e is ApiException
            ? e.message
            : 'Ulasan gagal dimuat. Coba lagi.';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slug != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final slug = (args is String && args.trim().isNotEmpty)
        ? args
        : widget.vendorName;
    if (slug == null || slug.trim().isEmpty) {
      _loading = false;
      _failed = true;
      return;
    }
    _slug = slug;
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<CatalogRepository>();
    final slug = _slug!;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final merchant = await repo.merchant(slug);
      final page = await repo.menus(merchant: slug, limit: 50);
      if (!mounted) return;
      setState(() {
        _merchant = merchant;
        _menus = page.items;
        _loading = false;
        // Menu bisa berubah: ulasan dimuat ulang saat tab Penilaian dibuka.
        _reviews = null;
        _reviewsError = null;
      });
      if (_selectedTabIndex == 2) _loadReviews();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<ProductModel> get _filteredMenus {
    var list = _menus;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              (m.description ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_selectedMenuCategory == 'Terlaris') {
      return list
          .where((m) =>
              (m.badgeText ?? '').toLowerCase().contains('terlaris') ||
              m.rating >= 4.8)
          .toList();
    } else if (_selectedMenuCategory == 'Paket & Katering') {
      return list.where((m) => m.category?.slug == 'katering').toList();
    } else if (_selectedMenuCategory == 'Danusan & Snack') {
      return list
          .where((m) => m.category?.slug == 'danusan' || m.category?.slug == 'manis')
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    AppColors.isDarkMode = isDark;

    if (_loading || _failed || _merchant == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat profil toko.'),
                    const SizedBox(height: 12),
                    if (_slug != null)
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Coba lagi'),
                      ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.count == 0) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: PrimaryButton(
                text: 'Lihat Keranjang (${cart.count})',
                gradient: AppColors.primaryGradient,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.checkout),
              ),
            ),
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Hero Cover + Overlapping Store Card (Gabungan GrabFood, GoFood, & ShopeeFood)
          SliverToBoxAdapter(
            child: _buildStoreHeroAndHeaderCard(isDark),
          ),

          // 2. Baris Promo & Voucher Dapur (Seperti ShopeeFood & GoFood)
          SliverToBoxAdapter(
            child: _buildPromoVouchersRow(isDark),
          ),

          // 3. Tab Bar Navigasi: Menu | Untukmu | Penilaian | Informasi (Seperti ShopeeFood)
          SliverToBoxAdapter(
            child: _buildNavigationTabs(isDark),
          ),

          // 4. Isi Konten Berdasarkan Tab Aktif
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: _buildActiveTabContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 1. HERO & FLOATING STORE CARD ====================

  Widget _buildStoreHeroAndHeaderCard(bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Banner Image
        Column(
          children: [
            SizedBox(
              height: 195,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.primary),
                  // Dark Gradient Overlay agar tombol atas terlihat jelas
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Ruang penampung bagian bawah kartu yang overlap
            const SizedBox(height: 162),
          ],
        ),

        // Top Floating Action Bar (Back, Search, Favorite, Share)
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCircleTopButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                const CartButton(),
                const SizedBox(width: 8),
                _buildCircleTopButton(
                  icon: _isSearching
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchQuery = '';
                      } else {
                        _selectedTabIndex = 0;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildCircleTopButton(
                  icon: _isStoreLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor:
                      _isStoreLiked ? AppColors.danger : AppColors.textPrimary,
                  onTap: () {
                    setState(() => _isStoreLiked = !_isStoreLiked);
                    _showToast(
                      _isStoreLiked
                          ? '${_vendor.businessName} disimpan ke Dapur Favorit'
                          : '${_vendor.businessName} dihapus dari Dapur Favorit',
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildCircleTopButton(
                  icon: Icons.share_outlined,
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Cek menu ${_vendor.businessName} di KateringKita! Rating ⭐ ${_vendor.ratingAvg}',
                      ),
                    );
                    _showToast('Tautan profil dapur berhasil disalin!');
                  },
                ),
              ],
            ),
          ),
        ),

        // Overlapping Store Info Card (Gabungan GrabFood Mie Gacoan & GoFood McDonald's)
        Positioned(
          left: 16,
          right: 16,
          top: 155,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Thumbnail Toko + Nama + Rating + Estimasi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto/Logo Toko
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MenuImage(
                        _vendor.logoUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama Toko + Badge Verified
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _vendor.businessName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vendor.merchantTypeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Baris Rating + Halal + Pelayanan Prima (Klik -> Tab Penilaian)
                          GestureDetector(
                            key: const ValueKey('store-rating'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _selectTab(2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 17,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${_vendor.ratingAvg}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '(${_vendor.ratingCount})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_vendor.isOpen ? 'Buka' : 'Tutup'} • ${_vendor.openTime}–${_vendor.closeTime} WIB',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleTopButton({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }

  // ==================== 2. PROMO VOUCHERS ROW ====================

  Widget _buildPromoVouchersRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari menu di ${_vendor.businessName}...',
                        hintStyle: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ==================== 3. NAVIGATION TABS ====================

  Widget _buildNavigationTabs(bool isDark) {
    final tabs = [
      'Menu (${_menus.length})',
      'Untukmu',
      'Penilaian',
      'Informasi',
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => _selectTab(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== 4. TAB CONTENTS ====================

  Widget _buildActiveTabContent(bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildMenuTab(isDark);
      case 1:
        return _buildForYouGridTab(isDark);
      case 2:
        return _buildReviewsTab();
      case 3:
        return _buildStoreInfoTab(isDark);
      default:
        return _buildMenuTab(isDark);
    }
  }

  /// TAB 2: Penilaian. Ringkasan dari rating toko (server) + ulasan terbaru
  /// dari menu-menu toko (lihat [loadStoreReviews]).
  Widget _buildReviewsTab() {
    final reviews = _reviews;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewSummary(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ulasan terbaru dari menu toko ini',
                  style: AppTextStyles.h4.copyWith(fontSize: 14),
                ),
              ),
              if (!_reviewsLoading)
                TextButton.icon(
                  onPressed: _loadReviews,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Muat ulang'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_reviewsLoading && reviews == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reviewsError != null && reviews == null)
            _reviewsMessage(
              _reviewsError!,
              action: OutlinedButton(
                  onPressed: _loadReviews, child: const Text('Coba Lagi')),
            )
          else if (reviews == null || reviews.reviews.isEmpty)
            _reviewsMessage('Belum ada ulasan untuk menu toko ini.')
          else ...[
            if (reviews.failed > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sebagian ulasan gagal dimuat.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ),
            for (final r in reviews.reviews) _reviewTile(r),
          ],
        ],
      ),
    );
  }

  Widget _stars(double value, {double size = 16}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => Icon(
            Icons.star_rounded,
            size: size,
            color: i < value.round()
                ? const Color(0xFFF59E0B)
                : AppColors.cardBorder,
          ),
        ),
      );

  Widget _reviewSummary() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Text(
              _vendor.ratingCount == 0
                  ? '–'
                  : _vendor.ratingAvg.toStringAsFixed(1),
              key: const ValueKey('store-rating-avg'),
              style: AppTextStyles.h1.copyWith(fontSize: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stars(_vendor.ratingAvg, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    _vendor.ratingCount == 0
                        ? 'Belum ada penilaian'
                        : 'Dari ${_vendor.ratingCount} penilaian',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reviewsMessage(String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined,
                  size: 40, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              if (action != null) ...[
                const SizedBox(height: 10),
                action,
              ],
            ],
          ),
        ),
      );

  Widget _reviewTile(StoreReview r) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.review.customerName,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  relativeTimeWib(r.review.createdAt),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _stars(r.review.rating.toDouble(), size: 14),
            if ((r.review.comment ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                r.review.comment!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Menu: ${r.menuName}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      );

  /// TAB 0: Daftar Menu Lengkap (Gaya ShopeeFood & GoFood dengan tombol + dan harga coret)
  Widget _buildMenuTab(bool isDark) {
    final categories = [
      'Semua',
      'Terlaris',
      'Danusan & Snack',
      'Paket & Katering',
    ];
    final items = _filteredMenus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Kategori Menu di Toko Ini
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedMenuCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMenuCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '$_selectedMenuCategory (${items.length})',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada menu di kategori ini',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final menu = items[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.productDetail,
                      arguments: menu,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto Menu dengan Badge Diskon & Pita Terlaris (Gaya ShopeeFood)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: MenuImage(menu.imageUrl,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: menu.badgeType == 'quota'
                                      ? AppColors.success
                                      : AppColors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(14),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  menu.badgeText ?? 'Terlaris',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                menu.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h4.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '⭐ ${menu.rating} (${menu.reviewCount})',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                menu.description ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppCurrency.format(menu.price),
                                        style: AppTextStyles.price.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Tombol + Oranye (Gaya ShopeeFood / GoFood)
                                  GestureDetector(
                                    onTap: !menu.canOrder
                                        ? null
                                        : () => addToCartWithPrompt(context, menu),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: menu.canOrder
                                            ? AppColors.primary
                                            : AppColors.textMuted,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }

  /// TAB 1: Grid 2 Kolom "Untukmu" (Persis Referensi GrabFood Screenshot 2)
  Widget _buildForYouGridTab(bool isDark) {
    final items = _menus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Untukmu di ${_vendor.businessName}',
            style: AppTextStyles.h3.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rekomendasi menu dari dapur ini',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.76,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final menu = items[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.productDetail,
                    arguments: menu,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(17),
                                ),
                                child: MenuImage(menu.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Tombol + Bulat di Pojok Kanan Atas Foto (Persis GrabFood)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: !menu.canOrder
                                    ? null
                                    : () => addToCartWithPrompt(context, menu),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            // Pita "Terlaris" di Bawah Foto (Persis GrabFood)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                color: isDark
                                    ? const Color(0xFF143823)
                                    : const Color(0xFFDCFCE7),
                                alignment: Alignment.center,
                                child: Text(
                                  menu.badgeText ?? 'Tersedia',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              menu.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppCurrency.format(menu.price),
                                  style: AppTextStyles.price.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${menu.rating}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
        ],
      ),
    );
  }

  /// TAB 3: Informasi Operasional Dapur (Sinkron 100% dengan Web `Pengaturan Toko & Operasional Dapur`)
  Widget _buildStoreInfoTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_vendor.description ?? '').isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                _vendor.description!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Kartu Detail Lokasi, Jam Buka & Kebijakan Holding 5 Menit
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Titik Temu / Pickup',
                  value: _vendor.pickupPoints.isEmpty
                      ? '-'
                      : _vendor.pickupPoints.map((e) => e.name).join(', '),
                ),
                Divider(height: 22, color: AppColors.cardBorder),
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  title: 'Jam Operasional Dapur',
                  value: '${_vendor.openTime}–${_vendor.closeTime} WIB',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


}
