import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/require_login.dart';
import '../../data/favorite_repository.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/menu_image.dart';

/// Daftar menu favorit pembeli dari `GET /me/favorites`.
///
/// Dimuat saat login dan dimuat ulang setiap favorit berubah di layar lain
/// (ditunda sampai tab ini terlihat). Menu yang baru dihapus dari favorit
/// langsung hilang dari daftar dan muncul lagi bila server menolak.
class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  static const _pageSize = 50;

  List<ProductModel> _items = const [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _seq = 0;
  bool _visible = true;
  bool _dirty = false;
  late final AuthProvider _auth;
  late final FavoritesProvider _favorites;
  late bool _wasLoggedIn;
  late int _seenRevision;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _favorites = context.read<FavoritesProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _seenRevision = _favorites.revision;
    _auth.addListener(_onAuthChanged);
    _favorites.addListener(_onFavoritesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _visible =
        TickerMode.valuesOf(context).enabled && (route?.isCurrent ?? true);
    if (_visible && _dirty) _load(silent: true);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _favorites.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (now == _wasLoggedIn || !mounted) return;
    _wasLoggedIn = now;
    if (now) {
      _load();
    } else {
      // Daftar milik akun sebelumnya dibuang.
      _seq++;
      setState(() {
        _items = const [];
        _total = 0;
        _page = 0;
        _error = null;
        _loading = false;
      });
    }
  }

  /// Favorit berubah di server (kartu/detail/daftar ini): muat ulang supaya
  /// menu baru ikut tampil. Perubahan optimistis tanpa hasil diabaikan.
  void _onFavoritesChanged() {
    if (_favorites.revision == _seenRevision) return;
    _seenRevision = _favorites.revision;
    if (!mounted || !_auth.isLoggedIn) return;
    if (_visible) {
      _load(silent: true);
    } else {
      _dirty = true;
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    _dirty = false;
    if (!_auth.isLoggedIn) {
      if (_loading) setState(() => _loading = false);
      return;
    }
    final repo = context.read<FavoriteRepository>();
    final seq = ++_seq;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await repo.list(limit: _pageSize);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _page = 1;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        if (!silent || _items.isEmpty) _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final repo = context.read<FavoriteRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final seq = _seq;
    setState(() => _loadingMore = true);
    try {
      final page = await repo.list(page: _page + 1, limit: _pageSize);
      if (!mounted || seq != _seq) return;
      final ids = _items.map((e) => e.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((e) => !ids.contains(e.id))];
        _total = page.total;
        _page++;
      });
    } catch (e) {
      if (mounted && seq == _seq) {
        messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  void _openDetail(ProductModel product) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    final favorites = context.watch<FavoritesProvider>();
    final shown = _items.where(favorites.isFavorite).toList();
    final removed = _items.length - shown.length;
    final count = loggedIn ? (_total - removed).clamp(0, _total) : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text(
                'Liked',
                style: AppTextStyles.h2.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Text(
                '$count Menu Favorit Tersimpan',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              if (!loggedIn)
                _guestPrompt()
              else if (_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && _items.isEmpty)
                _errorState()
              else if (shown.isEmpty)
                _emptyState()
              else ...[
                for (final product in shown) ...[
                  _item(product),
                  const SizedBox(height: 12),
                ],
                if (_items.length < _total)
                  Center(
                    child: _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: const Text('Muat lebih banyak'),
                          ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(IconData icon) => Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 32, color: AppColors.danger),
      );

  Widget _guestPrompt() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            _statusIcon(Icons.favorite_border_rounded),
            const SizedBox(height: 16),
            Text(
              'Masuk untuk melihat menu favoritmu',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Menu yang kamu simpan dengan ikon hati akan muncul di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              // Daftar dimuat oleh listener AuthProvider setelah login.
              onPressed: () => requireLogin(context),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );

  Widget _errorState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            _statusIcon(Icons.favorite_border_rounded),
            const SizedBox(height: 16),
            Text(
              'Belum ada menu favorit',
              style: AppTextStyles.h3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Tekan ikon hati pada menu untuk menyimpannya di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  Widget _item(ProductModel product) {
    final unavailable = !product.merchant.isOpen
        ? 'Toko sedang tutup'
        : product.badge == 'sold_out'
            ? 'Habis hari ini'
            : null;
    return GestureDetector(
      onTap: () => _openDetail(product),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MenuImage(
                product.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.vendor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppCurrency.format(product.price),
                    style: AppTextStyles.price.copyWith(fontSize: 14),
                  ),
                  if (unavailable != null)
                    Text(
                      unavailable,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            FavoriteButton(menu: product, size: 22),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _openDetail(product),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '+ Order',
                  style: AppTextStyles.button.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
