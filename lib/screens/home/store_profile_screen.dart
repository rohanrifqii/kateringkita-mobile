import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../models/cart_item.dart';
import '../../models/product_model.dart';
import '../../models/vendor_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cart_actions.dart';

class StoreProfileScreen extends StatefulWidget {
  final String? vendorName;

  const StoreProfileScreen({super.key, this.vendorName});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  late VendorProfile _vendor;
  bool _isDeliveryMode = true; // true = Pesan Antar, false = Pickup
  bool _isStoreLiked = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _selectedTabIndex = 0; // 0: Menu, 1: Untukmu, 2: Penilaian, 3: Informasi
  String _selectedMenuCategory = 'Semua';
  String _selectedReviewFilter = 'Semua';
  final Set<String> _claimedPromoIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is VendorProfile) {
      _vendor = args;
    } else if (args is String && args.trim().isNotEmpty) {
      _vendor = VendorData.getByVendorName(args);
    } else if (widget.vendorName != null &&
        widget.vendorName!.trim().isNotEmpty) {
      _vendor = VendorData.getByVendorName(widget.vendorName!);
    } else {
      _vendor = VendorData.vendors.first;
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

  Future<void> _contactVendorWhatsApp() async {
    final text = Uri.encodeComponent(
      'Halo ${_vendor.name}, saya pengguna aplikasi KateringKita ingin bertanya mengenai pemesanan menu katering/danusan.',
    );
    final url = Uri.parse('https://wa.me/${_vendor.whatsapp}?text=$text');
    final launched = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showToast('Nomor WhatsApp Dapur: +${_vendor.whatsapp}');
    }
  }

  // ==================== KERANJANG ====================

  /// Tambah 1 porsi ke keranjang (aturan 1 keranjang = 1 dapur ada di CartActions).
  Future<void> _addToCart(ProductModel menu) async {
    final cart = context.read<CartProvider>();
    final wasOtherVendor = cart.belongsToOtherVendor(menu.vendor);
    final ok = await CartActions.addProduct(context, menu);
    if (ok && wasOtherVendor) {
      _showToast('Keranjang diganti. ${menu.name} ditambahkan.');
    }
  }

  void _goToCheckout(CartProvider cart) {
    if (cart.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppRoutes.checkout,
      arguments: CheckoutRequest(
        items: cart.items.map((i) => i.copy()).toList(),
        fromCart: true,
      ),
    );
  }

  /// Tombol "+" (jika belum ada di keranjang) atau stepper "- [angka] +".
  /// Ketuk kotak angka untuk mengetik jumlah besar secara langsung (mis. 500 porsi).
  Widget _buildQtyControl(ProductModel menu, {bool overPhoto = false}) {
    final cart = context.watch<CartProvider>();
    // Hanya hitung qty jika keranjang milik dapur ini.
    final qty = cart.belongsToOtherVendor(menu.vendor)
        ? 0
        : cart.quantityOf(menu.id);

    Widget roundBtn(
      IconData icon,
      VoidCallback onTap, {
      VoidCallback? onLongPress,
      bool filled = true,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(overPhoto ? 16 : 9),
            border: filled
                ? null
                : Border.all(color: AppColors.primary, width: 1.3),
          ),
          child: Icon(
            icon,
            size: 19,
            color: filled ? Colors.white : AppColors.primary,
          ),
        ),
      );
    }

    if (qty == 0) {
      return roundBtn(
        Icons.add_rounded,
        () => _addToCart(menu),
        onLongPress: () => CartActions.promptAndSetCartQuantity(context, menu),
      );
    }

    return Container(
      padding: overPhoto
          ? const EdgeInsets.symmetric(horizontal: 3, vertical: 3)
          : EdgeInsets.zero,
      decoration: overPhoto
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
              ],
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          roundBtn(
            qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            () => cart.decrement(menu.id),
            filled: false,
          ),
          GestureDetector(
            onTap: () => CartActions.promptAndSetCartQuantity(context, menu),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minWidth: 38),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          roundBtn(
            Icons.add_rounded,
            () => _addToCart(menu),
            onLongPress: () =>
                CartActions.promptAndSetCartQuantity(context, menu),
          ),
        ],
      ),
    );
  }

  List<ProductModel> get _filteredMenus {
    var list = _vendor.menus;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.description.toLowerCase().contains(q))
          .toList();
    }
    if (_selectedMenuCategory == 'Terlaris') {
      return list
          .where((m) =>
              (m.badgeText ?? '').toLowerCase().contains('terlaris') ||
              m.rating >= 4.8)
          .toList();
    } else if (_selectedMenuCategory == 'Paket & Katering') {
      return list.where((m) => m.category == 'katering').toList();
    } else if (_selectedMenuCategory == 'Danusan & Snack') {
      return list
          .where((m) => m.category == 'danusan' || m.category == 'manis')
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    AppColors.isDarkMode = isDark;
    final cart = context.watch<CartProvider>();
    // Bar keranjang hanya muncul jika ada isi keranjang dari dapur ini.
    final showCartBar = !cart.isEmpty && cart.vendorName == _vendor.name;

    return Scaffold(
      backgroundColor: AppColors.background,
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
              padding: EdgeInsets.only(bottom: showCartBar ? 24 : 32),
              child: _buildActiveTabContent(isDark),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showCartBar ? _buildCartBar(cart) : null,
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
                  Image.asset(
                    _vendor.bannerImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.primary,
                    ),
                  ),
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
                  // Banner pengumuman kecil ala GrabFood
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 48,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            color: Color(0xFFFBBF24),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Mitra Resmi Kampus UB Ã¢â‚¬Â¢ ${_vendor.serviceMode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                // Pill status pengantaran seperti GrabFood
                GestureDetector(
                  onTap: () =>
                      setState(() => _isDeliveryMode = !_isDeliveryMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isDeliveryMode
                              ? Icons.delivery_dining_rounded
                              : Icons.storefront_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isDeliveryMode ? 'Antar' : 'Ambil',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
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
                // Chat Dapur (WhatsApp) dipindah ke header, bukan di bawah.
                _buildCircleTopButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF16A34A),
                  onTap: _contactVendorWhatsApp,
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
                          ? '${_vendor.name} disimpan ke Dapur Favorit'
                          : '${_vendor.name} dihapus dari Dapur Favorit',
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
                            'Cek menu katering ${_vendor.name} (${_vendor.area}) di KateringKita! Rating Ã¢Â­Â ${_vendor.rating}',
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
                      child: Image.asset(
                        _vendor.logoImage,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.primarySoft,
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
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
                                  _vendor.name,
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
                            '- ${_vendor.area}',
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
                            onTap: () {
                              setState(() => _selectedTabIndex = 2);
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 17,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${_vendor.rating}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '(${_vendor.reviewCountLabel}) Ã¢â‚¬Â¢ Halal Ã¢â‚¬Â¢ Pelayanan Prima',
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
                          // Info Ongkir & Estimasi Waktu
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Gratis Ongkir',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Rp7.000',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Ã¢â‚¬Â¢ ${_vendor.etaMinutes} (${_vendor.distanceKm})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 14),

                // Toggle Pill: Pesan Antar (Delivery) | Pickup (Seperti ShopeeFood & GoFood)
                Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDeliveryMode = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: _isDeliveryMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Pesan Antar (Delivery)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _isDeliveryMode
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isDeliveryMode = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: !_isDeliveryMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Pickup Ã¢â‚¬Â¢ ${_vendor.distanceKm}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: !_isDeliveryMode
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        hintText: 'Cari menu di ${_vendor.name}...',
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: _vendor.promos.map((promo) {
              final isClaimed = _claimedPromoIds.contains(promo.id);
              final accentColor = promo.isFreeShipping
                  ? const Color(0xFF0D9488)
                  : AppColors.primary;
              final bgSoft = promo.isFreeShipping
                  ? (isDark
                      ? const Color(0xFF112E2B)
                      : const Color(0xFFF0FDFA))
                  : AppColors.primarySoft;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _claimedPromoIds.add(promo.id));
                    _showToast(
                      'Voucher "${promo.title}" (${promo.code}) berhasil diklaim!',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bgSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            promo.isFreeShipping
                                ? Icons.local_shipping_rounded
                                : Icons.confirmation_number_rounded,
                            color: accentColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              promo.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              promo.subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isClaimed
                                ? AppColors.surface
                                : accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isClaimed ? 'Ã¢Å“â€œ Diklaim' : 'Klaim',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isClaimed ? accentColor : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==================== 3. NAVIGATION TABS ====================

  Widget _buildNavigationTabs(bool isDark) {
    final tabs = [
      'Menu (${_vendor.menus.length})',
      'Untukmu',
      'Penilaian (${_vendor.reviewCountLabel})',
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
              onTap: () => setState(() => _selectedTabIndex = index),
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
        return _buildReviewsTab(isDark);
      case 3:
        return _buildStoreInfoTab(isDark);
      default:
        return _buildMenuTab(isDark);
    }
  }

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
                final originalPrice = (menu.price * 1.15).roundToDouble();

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
                              child: Image.asset(
                                menu.image,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 92,
                                  height: 92,
                                  color: AppColors.secondaryBg,
                                  child: Icon(
                                    Icons.fastfood_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF08A),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(14),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  '-15%',
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
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
                                '${menu.reviewCount}+ terjual  |  Ã¢Â­Â ${menu.rating}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                menu.description,
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
                                        AppCurrency.format(originalPrice),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      Text(
                                        AppCurrency.format(menu.price),
                                        style: AppTextStyles.price.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Tombol + / stepper (Gaya ShopeeFood / GoFood)
                                  _buildQtyControl(menu),
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
    final items = _vendor.menus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Untukmu di ${_vendor.name}',
            style: AppTextStyles.h3.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rekomendasi menu paling sering dipesan mahasiswa minggu ini',
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
                                child: Image.asset(
                                  menu.image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Tombol + Bulat di Pojok Kanan Atas Foto (Persis GrabFood)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: _buildQtyControl(menu, overPhoto: true),
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
                                  'Terlaris',
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

  /// TAB 2: Penilaian & Ulasan Pembeli (Menjawab kebutuhan user untuk melihat rating & reputasi dapur)
  Widget _buildReviewsTab(bool isDark) {
    final filters = [
      'Semua',
      '5 Bintang',
      'Cocok Danusan',
      'Tepat Waktu',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kartu Ringkasan Skor Rating Dapur
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      '${_vendor.rating}',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_vendor.reviewCountLabel} Penilaian',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Container(
                  width: 1,
                  height: 74,
                  color: AppColors.cardBorder,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      _buildStarBar(5, 0.88),
                      const SizedBox(height: 5),
                      _buildStarBar(4, 0.10),
                      const SizedBox(height: 5),
                      _buildStarBar(3, 0.02),
                      const SizedBox(height: 5),
                      _buildStarBar(2, 0.0),
                      const SizedBox(height: 5),
                      _buildStarBar(1, 0.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter Chips Ulasan
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final selected = _selectedReviewFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedReviewFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primarySoft
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
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
          const SizedBox(height: 14),

          // Daftar Kartu Ulasan Mahasiswa
          ..._vendor.reviews.map((rev) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          rev.userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rev.userName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              rev.userRole,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF59E0B),
                                size: 15,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${rev.rating}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            rev.date,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rev.comment,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Memesan: ${rev.orderedMenu}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rev.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rev.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Ã°Å¸â€˜Â $tag',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStarBar(int star, double ratio) {
    return Row(
      children: [
        Text(
          '$star',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.secondaryBg,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
        ),
      ],
    );
  }

  /// TAB 3: Informasi Operasional Dapur (Sinkron 100% dengan Web `Pengaturan Toko & Operasional Dapur`)
  Widget _buildStoreInfoTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kartu Karakteristik Layanan Dapur (Sesuai Web Dashboard)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.layers_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KARAKTERISTIK LAYANAN DAPUR',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            _vendor.serviceMode,
                            style: AppTextStyles.h4.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF143823)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ã¢â€”Â Aktif Ã¢Å“â€œ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _vendor.serviceModeDesc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

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
                  title: 'Alamat / Lokasi Dapur di Kampus',
                  value: _vendor.fullAddress,
                ),
                Divider(height: 22, color: AppColors.cardBorder),
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  title: 'Jam Operasional Dapur',
                  value: '${_vendor.openHours} (Buka Setiap Hari Kuliah)',
                ),
                Divider(height: 22, color: AppColors.cardBorder),
                _buildInfoRow(
                  icon: Icons.timer_outlined,
                  title: 'Kebijakan Penguncian Kuota (Lock)',
                  value:
                      'Holding Timer 5 Menit otomatis saat Checkout untuk mencegah pesanan dobel.',
                ),
                Divider(height: 22, color: AppColors.cardBorder),
                _buildInfoRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Sertifikasi & Jaminan Higienis',
                  value:
                      '100% Halal Ã¢â‚¬Â¢ Bahan Segar Harian Ã¢â‚¬Â¢ Terverifikasi BEM/Kantin Kampus UB',
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

  // ==================== BAR KERANJANG (muncul hanya jika ada isi) ====================

  Widget _buildCartBar(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showCartSheet,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '${cart.itemCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  AppCurrency.format(cart.totalPrice),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.price.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          Text(
                            '${cart.items.length} menu â€¢ ${cart.itemCount} porsi',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _goToCheckout(cart),
              child: const Text(
                'Checkout',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet rincian keranjang: ubah jumlah, hapus menu, kosongkan, checkout.
  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer<CartProvider>(
          builder: (ctx, cart, _) {
            // Keranjang habis (mis. semua dihapus) -> tutup sheet otomatis.
            if (cart.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              });
              return const SizedBox(height: 120);
            }
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keranjang Pesanan',
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _vendor.name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => cart.clear(),
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            label: const Text(
                              'Kosongkan',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: AppColors.cardBorder),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        itemCount: cart.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          final item = cart.items[index];
                          return Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  item.product.image,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 54,
                                    height: 54,
                                    color: AppColors.secondaryBg,
                                    child: Icon(
                                      Icons.fastfood,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      AppCurrency.format(item.subtotal),
                                      style: AppTextStyles.price.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildSheetStepper(cart, item),
                            ],
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: AppColors.cardBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subtotal',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  AppCurrency.format(cart.totalPrice),
                                  style: AppTextStyles.price.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _goToCheckout(cart);
                            },
                            child: const Text(
                              'Checkout',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetStepper(CartProvider cart, CartItem item) {
    Widget btn(IconData icon, VoidCallback onTap, {bool filled = false}) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: filled
                ? null
                : Border.all(color: AppColors.primary, width: 1.3),
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : AppColors.primary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          item.quantity == 1
              ? Icons.delete_outline_rounded
              : Icons.remove_rounded,
          () => cart.decrement(item.id),
        ),
        GestureDetector(
          onTap: () =>
              CartActions.promptAndSetCartQuantity(context, item.product),
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        btn(Icons.add_rounded, () => cart.add(item.product), filled: true),
      ],
    );
  }
}