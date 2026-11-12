import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../api/api_exception.dart';
import '../../data/catalog_repository.dart';
import '../../data/settings_store.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/food_card.dart';
import '../../widgets/notification_bell.dart';
import '../orders/location_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _BannerAction { search, orders, assistant }

/// Banner informasi layanan. Backend tidak punya promo publik (promo hanya
/// kode di checkout), jadi banner tidak menjanjikan diskon atau pengantaran.
class _InfoBanner {
  const _InfoBanner({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.image,
    this.cta,
    this.action,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String image;

  /// Tanpa [cta]/[action] tombol tidak ditampilkan.
  final String? cta;
  final _BannerAction? action;
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Semua';
  String? _selectedSlug;
  String _meetingPoint = SettingsStore.defaultMeetingPoint;

  List<CategoryModel> _categories = const [];
  List<ProductModel> _products = const [];
  bool _loading = true;
  int _seq = 0;
  String? _error;

  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();

  static const List<_InfoBanner> _infoBanners = [
    _InfoBanner(
      tag: 'TITIK TEMU',
      title: 'Ambil di Titik Temu',
      subtitle:
          'Pilih titik temu kampus saat checkout, lalu ambil pesananmu di sana.',
      cta: 'Cari Menu →',
      action: _BannerAction.search,
      image: 'assets/images/nasi_kuning.png',
    ),
    _InfoBanner(
      tag: 'PEMBAYARAN',
      title: 'VA, QRIS & E-Wallet',
      subtitle: 'Bayar lewat Midtrans: VA BCA, BNI, BRI, atau QRIS & e-wallet.',
      cta: 'Lihat Pesanan →',
      action: _BannerAction.orders,
      image: 'assets/images/lumpia_diego.png',
    ),
    _InfoBanner(
      tag: 'UNTUK ACARA',
      title: 'Atur Waktu Ambil',
      subtitle:
          'Pilih tanggal & jam ambil hingga 7 hari ke depan untuk acaramu.',
      cta: 'Tanya AI →',
      action: _BannerAction.assistant,
      image: 'assets/images/banner_promo.png',
    ),
  ];

  /// Tab di MainNavigationScreen; bila Home dibuka sendiri, rute biasa.
  void _onBannerTap(_BannerAction action) {
    final tab = widget.onTabChange;
    switch (action) {
      case _BannerAction.search:
        Navigator.pushNamed(context, AppRoutes.search);
      case _BannerAction.orders:
        if (tab != null) {
          tab(1);
        } else {
          Navigator.pushNamed(context, AppRoutes.orders);
        }
      case _BannerAction.assistant:
        if (tab != null) {
          tab(2);
        } else {
          Navigator.pushNamed(context, AppRoutes.aiAssistant);
        }
    }
  }

  late final AuthProvider _auth;
  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    _loadMeetingPoint();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _bannerController.dispose();
    super.dispose();
  }

  /// Masuk/keluar: muat ulang menu supaya `is_favorite` milik sesi yang benar.
  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (now == _wasLoggedIn || !mounted) return;
    _wasLoggedIn = now;
    _load();
  }

  Future<void> _loadMeetingPoint() async {
    final point = await SettingsStore.loadMeetingPoint();
    if (!mounted) return;
    setState(() => _meetingPoint = point);
  }

  Future<void> _pickMeetingPoint() async {
    final (lat, lng) = await SettingsStore.loadMeetingCoordinates();
    if (!mounted) return;
    final result = await Navigator.push<DeliveryLocation>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          currentLocationName: _meetingPoint,
          initialLat: lat,
          initialLng: lng,
        ),
      ),
    );
    if (result != null) {
      await SettingsStore.saveMeetingPoint(
        result.name,
        fullAddress: result.fullAddress,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      setState(() => _meetingPoint = result.name);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = context.read<CatalogRepository>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = _categories.isEmpty ? await repo.categories() : _categories;
      final page = await repo.menus(category: _selectedSlug);
      if (!mounted || seq != _seq) return;
      setState(() {
        _categories = cats;
        _products = page.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
      });
    }
  }

  void _selectCategory(CategoryModel? c) {
    setState(() {
      _selectedCategory = c?.name ?? 'Semua';
      _selectedSlug = c?.slug;
    });
    _load();
  }

  void _showCategoryFilterSheet() {
    final filterOptions = <Map<String, dynamic>>[
      {'label': 'Semua Menu', 'cat': null},
      for (final c in _categories) {'label': c.name, 'cat': c},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Kategori Menu',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filterOptions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filterOptions[index];
                      final cat = item['cat'] as CategoryModel?;
                      final isSelected = _selectedSlug == cat?.slug;
                      return ListTile(
                        leading: Icon(
                          Icons.restaurant_menu_rounded,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        title: Text(
                          item['label'] as String,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _selectCategory(cat);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
         onRefresh: _load,
         child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- TOP BAR (FIGMA) ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KateringKita',
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: _pickMeetingPoint,
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$_meetingPoint ▾',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const CartButton(),
                  const SizedBox(width: 8),
                  // Lonceng dengan lencana jumlah belum dibaca
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 20),

              // ---------------- SEARCH BAR (FIGMA) ----------------
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.search);
                        },
                        child: Text(
                          _selectedCategory == 'Semua'
                              ? 'Search products, katering, danus...'
                              : 'Kategori: $_selectedCategory',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _selectedCategory == 'Semua'
                                ? AppColors.textMuted
                                : AppColors.primary,
                            fontSize: 13,
                            fontWeight: _selectedCategory == 'Semua'
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_selectedCategory != 'Semua')
                      GestureDetector(
                        onTap: () => _selectCategory(null),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                        ),
                      ),
                    // Tombol Kategori Tune Icon
                    GestureDetector(
                      onTap: _showCategoryFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedCategory != 'Semua'
                              ? AppColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: _selectedCategory != 'Semua'
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------------- CATEGORY PILLS (FIGMA) ----------------
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length + 1, (index) {
                    final CategoryModel? cat =
                        index == 0 ? null : _categories[index - 1];
                    final category = cat?.name ?? 'Semua';
                    final isSelected = _selectedSlug == cat?.slug;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          _selectCategory(isSelected ? null : cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.cardBorder,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            category,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // ---------------- BANNER INFO LAYANAN ----------------
              SizedBox(
                width: double.infinity,
                height: 172,
                child: PageView.builder(
                  controller: _bannerController,
                  itemCount: _infoBanners.length,
                  onPageChanged: (index) {
                    setState(() => _currentBannerIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final banner = _infoBanners[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background Image
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                banner.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          // Dark/Orange Gradient Overlay
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      const Color(0xFF1A130D).withValues(alpha: 0.92),
                                      const Color(0xFF1A130D).withValues(alpha: 0.65),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Banner Content
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    banner.tag,
                                    style: AppTextStyles.badge.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  banner.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h2.copyWith(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFFFEF3C7),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                if (banner.cta != null &&
                                    banner.action != null) ...[
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => _onBannerTap(banner.action!),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        banner.cta!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_infoBanners.length, (index) {
                  final isSelected = _currentBannerIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),

              // ---------------- DAFTAR MENU HEADER ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory == 'Semua'
                        ? 'Daftar Menu (${products.length})'
                        : '$_selectedCategory (${products.length})',
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Semua halal & higienis',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ---------------- PRODUCT GRID (FIGMA) ----------------
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h4.copyWith(fontSize: 14)),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              else if (products.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada menu yang tersedia saat ini.',
                        style: AppTextStyles.h4.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.76,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return FoodGridCard(
                      product: product,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.productDetail,
                          arguments: product,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
         ),
        ),
      ),
    );
  }
}
