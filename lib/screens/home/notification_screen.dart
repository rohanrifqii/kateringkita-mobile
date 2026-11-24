// Layar Notifikasi: dibuka dari ikon lonceng di Beranda. Daftarnya diambil dari server lewat NotificationRepository
// (GET /me/notifications, tandai dibaca lewat POST /me/notifications/read) dan jumlah belum dibaca disinkronkan ke
// NotificationProvider supaya lencana lonceng ikut berubah. Tamu hanya melihat ajakan masuk.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/relative_time.dart';
import '../../core/require_login.dart';
import '../../data/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

/// Nama tab layar Pesanan ('active', 'completed', atau 'cancelled') yang memuat pesanan berstatus [status];
/// status 'expired' ikut tab 'cancelled', status lain atau null jatuh ke 'active'.
String orderTabForStatus(String? status) => switch (status) {
      'completed' => 'completed',
      'cancelled' || 'expired' => 'cancelled',
      _ => 'active',
    };

/// Layar daftar notifikasi in-app milik pengguna yang login, diambil dari `GET /me/notifications` dengan paginasi
/// 20 per halaman, filter chip per tipe, tandai dibaca satu per satu atau sekaligus, dan tarik-untuk-muat-ulang.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

/// State layar Notifikasi: memegang daftar yang sudah dimuat, halaman terakhir, dan status muat/galat.
class _NotificationScreenState extends State<NotificationScreen> {
  /// Jumlah notifikasi per halaman yang diminta ke server.
  static const _pageSize = 20;

  /// Label chip → nilai `type` yang dikirim ke server (null = semua tipe).
  static const _categories = <String, String?>{
    'Semua': null,
    'Pesanan': 'order_status',
    'Promo': 'promo',
    'Info': 'info',
  };

  String _selectedCategory = 'Semua';

  /// Nilai `type` untuk chip yang sedang dipilih.
  String? get _type => _categories[_selectedCategory];
  List<AppNotification> _items = const [];

  /// Jumlah total notifikasi menurut server; dipakai untuk menentukan apakah tombol "Muat lebih banyak" tampil.
  int _total = 0;

  /// Halaman terakhir yang sudah dimuat (0 = belum ada).
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;

  /// Nomor urut permintaan: jawaban server yang datang setelah chip diganti atau pengguna keluar (nomornya sudah
  /// tidak sama) dibuang supaya tidak menimpa daftar yang lebih baru.
  int _seq = 0;
  late final AuthProvider _auth;

  /// Status login terakhir yang diketahui, untuk mendeteksi perubahan masuk/keluar di [_onAuthChanged].
  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    // Muat setelah frame pertama supaya context.read di _load aman dipakai.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Dipanggil AuthProvider: setelah login daftar dimuat; setelah keluar daftar dikosongkan dan permintaan yang
  /// masih berjalan dibatalkan dengan menaikkan [_seq].
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

  /// Ganti chip: muat ulang dari server dengan `type` chip itu (paginasi
  /// mulai lagi dari halaman 1).
  void _selectCategory(String category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      _items = const [];
      _total = 0;
      _page = 0;
      _error = null;
    });
    _load();
  }

  /// Pesan galat untuk pengguna: pesan dari server bila galatnya [ApiException], selain itu pesan umum.
  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  /// Menampilkan snackbar mengambang, menggantikan snackbar yang sedang tampil.
  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ));

  /// Memuat halaman pertama dari `GET /me/notifications` (dengan `type` chip aktif) dan menyamakan lencana belum
  /// dibaca. [silent] = true dipakai tarik-untuk-muat-ulang: tanpa indikator muat, dan galat hanya ditampilkan bila
  /// daftar masih kosong. Tamu tidak memanggil server.
  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!_auth.isLoggedIn) {
      if (_loading) setState(() => _loading = false);
      return;
    }
    final repo = context.read<NotificationRepository>();
    final badge = context.read<NotificationProvider>();
    final seq = ++_seq;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await repo.list(limit: _pageSize, type: _type);
      if (!mounted || seq != _seq) return;
      badge.setUnread(page.unreadCount);
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

  /// Memuat halaman berikutnya lalu menambahkannya ke daftar; notifikasi yang id-nya sudah ada dilewati supaya
  /// tidak dobel bila ada notifikasi baru yang menggeser halaman. Galat ditampilkan sebagai snackbar.
  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final repo = context.read<NotificationRepository>();
    final badge = context.read<NotificationProvider>();
    final seq = _seq;
    setState(() => _loadingMore = true);
    try {
      final page =
          await repo.list(page: _page + 1, limit: _pageSize, type: _type);
      if (!mounted || seq != _seq) return;
      badge.setUnread(page.unreadCount);
      final ids = _items.map((e) => e.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((e) => !ids.contains(e.id))];
        _total = page.total;
        _page++;
      });
    } catch (e) {
      if (mounted && seq == _seq) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Tombol "Tandai Dibaca": `POST /me/notifications/read` dengan `{all: true}`, lencana diisi sisa belum dibaca
  /// dari server, dan semua item yang sudah dimuat ditandai dibaca di layar.
  Future<void> _markAllAsRead() async {
    if (_markingAll) return;
    final repo = context.read<NotificationRepository>();
    final badge = context.read<NotificationProvider>();
    final seq = _seq;
    setState(() => _markingAll = true);
    try {
      final left = await repo.markAllRead();
      if (!mounted || seq != _seq) return;
      badge.setUnread(left);
      final now = DateTime.now().toUtc();
      setState(() => _items = [for (final n in _items) n.markedRead(now)]);
      _snack('Semua notifikasi telah ditandai sudah dibaca');
    } catch (e) {
      if (mounted && seq == _seq) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  /// Mengganti item dengan id yang sama di daftar (tidak berbuat apa-apa bila tidak ada).
  void _replace(AppNotification n) {
    final i = _items.indexWhere((e) => e.id == n.id);
    if (i < 0) return;
    setState(() => _items = [..._items]..[i] = n);
  }

  /// Ditandai dibaca langsung (dikembalikan bila server menolak), lalu
  /// notifikasi pesanan membuka daftar Pesanan di tab & kode yang sesuai,
  /// dan notifikasi tiket (`data.ticket_code`) membuka detail tiket itu.
  Future<void> _open(AppNotification n) async {
    // Tidak ditunggu: navigasi tidak perlu menunggu jawaban server.
    if (!n.isRead) _markRead(n);
    final ticket = n.ticketCode;
    if (ticket != null) {
      await Navigator.pushNamed(context, AppRoutes.ticketDetail,
          arguments: ticket);
      return;
    }
    final code = n.orderCode;
    if (n.isOrderStatus && code != null && code.isNotEmpty) {
      await Navigator.pushNamed(context, AppRoutes.orders, arguments: {
        'tab': orderTabForStatus(n.orderStatus),
        'q': code,
      });
    }
  }

  /// Menandai satu notifikasi dibaca secara optimistis (tampilan dan lencana langsung berubah), lalu mengirim
  /// `POST /me/notifications/read` dengan id-nya. Bila gagal, item dan lencana dikembalikan seperti semula.
  Future<void> _markRead(AppNotification n) async {
    final repo = context.read<NotificationRepository>();
    final badge = context.read<NotificationProvider>();
    final seq = _seq;
    _replace(n.markedRead(DateTime.now().toUtc()));
    badge.setUnread(badge.unreadCount - 1);
    try {
      final left = await repo.markRead([n.id]);
      // Lencana disamakan dengan sisa belum dibaca menurut server.
      if (mounted && seq == _seq) badge.setUnread(left);
    } catch (_) {
      if (!mounted || seq != _seq) return;
      _replace(n);
      badge.setUnread(badge.unreadCount + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    final unread = context.watch<NotificationProvider>().unreadCount;
    // Tombol "Tandai Dibaca" tampil bila lencana > 0 atau masih ada item belum dibaca di layar.
    final hasUnread = unread > 0 || _items.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifikasi',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (loggedIn && hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _markAllAsRead,
              child: const Text(
                'Tandai Dibaca',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: !loggedIn
          ? _guestPrompt()
          : Column(
              children: [
                _filterChips(),
                Expanded(child: _body()),
              ],
            ),
    );
  }

  /// Baris chip kategori yang bisa digeser mendatar; mengetuk chip memanggil [_selectCategory].
  Widget _filterChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: _categories.keys.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _selectCategory(cat),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  /// Isi daftar: indikator muat, pesan galat dengan "Coba Lagi", pesan kosong, atau kartu notifikasi plus tombol
  /// "Muat lebih banyak" selama jumlah yang dimuat masih di bawah total server.
  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Sudah difilter server sesuai chip (type).
    final list = _items;
    final hasMore = _items.length < _total;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (_error != null && _items.isEmpty)
            _message(
              icon: Icons.cloud_off_rounded,
              title: _error!,
              action: OutlinedButton(
                  onPressed: _load, child: const Text('Coba Lagi')),
            )
          else if (list.isEmpty)
            _message(
              icon: Icons.notifications_none_rounded,
              title: 'Tidak ada notifikasi',
              subtitle: _selectedCategory == 'Semua'
                  ? 'Kabar pesanan, promo, dan info akan muncul di sini.'
                  : 'Kategori "$_selectedCategory" saat ini kosong.',
            )
          else
            for (final item in list) ...[
              _tile(item),
              const SizedBox(height: 10),
            ],
          if (hasMore && _error == null)
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
      ),
    );
  }

  /// Pesan di tengah daftar (ikon, judul, subjudul, dan tombol opsional) untuk keadaan kosong atau galat.
  Widget _message({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      );

  /// Tampilan untuk tamu: ajakan masuk dengan tombol yang membuka alur login.
  Widget _guestPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Masuk untuk melihat notifikasi',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Kabar status pesananmu akan muncul di sini.',
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
        ),
      );

  /// Ikon dan warna kartu menurut tipe notifikasi; notifikasi pesanan dibedakan lagi menurut status pesanannya.
  (IconData, Color) _iconOf(AppNotification n) {
    switch (n.type) {
      case 'order_status':
        return switch (n.orderStatus) {
          'ready' => (Icons.check_circle_outline_rounded, AppColors.success),
          'cooking' => (Icons.soup_kitchen_outlined, AppColors.warning),
          'cancelled' ||
          'expired' =>
            (Icons.cancel_outlined, AppColors.danger),
          _ => (Icons.receipt_long_rounded, AppColors.primary),
        };
      case 'promo':
        return (Icons.local_offer_outlined, AppColors.primary);
      case _ when n.ticketCode != null:
        return (Icons.support_agent_rounded, AppColors.primary);
      default:
        return (Icons.campaign_outlined, AppColors.blue);
    }
  }

  /// Kartu satu notifikasi: latar berwarna dan titik penanda bila belum dibaca, waktu relatif (WIB) di bawah isi.
  Widget _tile(AppNotification item) {
    final (icon, color) = _iconOf(item);
    return InkWell(
      onTap: () => _open(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? AppColors.surface : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? AppColors.cardBorder
                : AppColors.primary.withValues(alpha: 0.35),
            width: item.isRead ? 1 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          key: ValueKey('unread-${item.id}'),
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    relativeTimeWib(item.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
