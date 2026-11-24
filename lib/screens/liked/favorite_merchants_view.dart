// Segmen "Toko" (Dapur Favorit) di layar Favorit: daftar toko yang disimpan pengguna, diambil dari backend
// lewat FavoriteRepository (GET /me/favorite-merchants). Status hati tiap toko dibaca dari FavoritesProvider.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/catalog_repository.dart';
import '../../data/favorite_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/menu_image.dart';

/// Segmen "Toko" di layar Favorit: `GET /me/favorite-merchants`, 50 toko per halaman.
///
/// Dimuat saat segmen dibuka, saat login, dan setiap Dapur Favorit berubah
/// (termasuk dari layar lain). Toko yang baru dihapus langsung hilang dan
/// muncul lagi bila server menolak. Hanya dipakai saat sudah login.
class FavoriteMerchantsView extends StatefulWidget {
  const FavoriteMerchantsView({super.key});

  @override
  State<FavoriteMerchantsView> createState() => _FavoriteMerchantsViewState();
}

/// State segmen Toko: daftar toko yang sudah dimuat, halaman terakhir, dan status muat/galat.
class _FavoriteMerchantsViewState extends State<FavoriteMerchantsView> {
  static const _pageSize = 50;

  List<MerchantProfile> _items = const [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  /// Nomor urut permintaan; jawaban yang datang setelah ada permintaan lebih baru atau setelah logout diabaikan.
  int _seq = 0;
  late final AuthProvider _auth;
  late final FavoritesProvider _favorites;
  late bool _wasLoggedIn;
  /// [FavoritesProvider.merchantRevision] terakhir yang sudah dimuat; bila naik, daftar dimuat ulang.
  late int _seenRevision;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _favorites = context.read<FavoritesProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _seenRevision = _favorites.merchantRevision;
    _auth.addListener(_onAuthChanged);
    _favorites.addListener(_onFavoritesChanged);
    // Muat setelah frame pertama agar setState di _load tidak terjadi saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _favorites.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  /// Login: muat daftar. Logout: batalkan permintaan yang berjalan dan kosongkan daftar.
  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (now == _wasLoggedIn || !mounted) return;
    _wasLoggedIn = now;
    if (now) {
      _load();
    } else {
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

  /// Muat ulang diam-diam (tanpa pemutar) bila daftar toko favorit di server berubah.
  void _onFavoritesChanged() {
    if (_favorites.merchantRevision == _seenRevision) return;
    _seenRevision = _favorites.merchantRevision;
    if (mounted && _auth.isLoggedIn) _load(silent: true);
  }

  /// Pesan galat untuk pengguna: pesan dari server bila ada, selain itu pesan umum.
  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  /// Muat halaman pertama dari GET /me/favorite-merchants. [silent] = tanpa pemutar
  /// dan galat tidak ditampilkan bila daftar lama masih ada (dipakai tarik-untuk-segarkan).
  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
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
      final page = await repo.listMerchants(limit: _pageSize);
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

  /// Muat halaman berikutnya dan sambungkan ke daftar; toko yang sudah ada tidak digandakan.
  /// Galat ditampilkan sebagai snackbar.
  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final repo = context.read<FavoriteRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final seq = _seq;
    setState(() => _loadingMore = true);
    try {
      final page = await repo.listMerchants(page: _page + 1, limit: _pageSize);
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

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    // Toko yang baru dilepas hatinya langsung disembunyikan, dan jumlahnya ikut dikurangi.
    final shown = _items.where(favorites.isFavoriteMerchant).toList();
    final removed = _items.length - shown.length;
    final count = (_total - removed).clamp(0, _total);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            '$count Dapur Favorit Tersimpan',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _items.isEmpty)
            _message(
              Icons.cloud_off_rounded,
              _error!,
              action:
                  OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
            )
          else if (shown.isEmpty)
            _message(
              Icons.storefront_outlined,
              'Belum ada Dapur Favorit',
              subtitle:
                  'Tekan ikon hati di profil toko untuk menyimpannya di sini.',
            )
          else ...[
            for (final m in shown) ...[
              _card(m),
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
    );
  }

  /// Tampilan pesan di tengah (kosong/galat) dengan ikon, subjudul, dan tombol opsional.
  Widget _message(IconData icon, String title,
          {String? subtitle, Widget? action}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(fontSize: 15),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      );

  /// Kartu satu toko: logo, jam buka, penilaian, dan tombol hati. Ketuk kartu membuka profil toko.
  Widget _card(MerchantProfile m) {
    final liked = context.watch<FavoritesProvider>().isFavoriteMerchant(m);
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.storeProfile, arguments: m.slug),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            MenuImage(
              m.logoUrl,
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${m.merchantTypeName} • '
                    '${m.isOpen ? 'Buka' : 'Tutup'} '
                    '${m.openTime}–${m.closeTime} WIB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: m.isOpen
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.warning, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        m.ratingCount == 0
                            ? 'Belum ada penilaian'
                            : '${m.ratingAvg.toStringAsFixed(1)} '
                                '(${m.ratingCount})',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: liked ? 'Hapus dari Dapur Favorit' : 'Simpan ke Dapur Favorit',
              icon: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: liked ? AppColors.danger : AppColors.textPrimary,
                size: 22,
              ),
              onPressed: () => toggleFavoriteMerchant(context, m),
            ),
          ],
        ),
      ),
    );
  }
}
