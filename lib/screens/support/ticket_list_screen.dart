import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/relative_time.dart';
import '../../core/require_login.dart';
import '../../data/ticket_repository.dart';
import '../../models/support_ticket.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_unread_provider.dart';
import 'ticket_widgets.dart';

/// Daftar tiket Bantuan milik pembeli (`GET /me/tickets`).
///
/// Dimuat ulang diam-diam setiap kali layar ini kembali terlihat (setelah
/// membuka detail atau membuat tiket), jadi status & titik belum dibaca
/// selalu mengikuti server.
class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  static const _pageSize = 20;

  List<TicketSummary> _items = const [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _seq = 0;
  bool _wasCurrent = true;
  late final AuthProvider _auth;
  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_wasCurrent && !_loading) _load(silent: true);
    _wasCurrent = current;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

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

  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ));

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!_auth.isLoggedIn) {
      if (_loading) setState(() => _loading = false);
      return;
    }
    final repo = context.read<TicketRepository>();
    final badge = context.read<TicketUnreadProvider>();
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

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final repo = context.read<TicketRepository>();
    final badge = context.read<TicketUnreadProvider>();
    final seq = _seq;
    setState(() => _loadingMore = true);
    try {
      final page = await repo.list(page: _page + 1, limit: _pageSize);
      if (!mounted || seq != _seq) return;
      badge.setUnread(page.unreadCount);
      final codes = _items.map((e) => e.code).toSet();
      setState(() {
        _items = [
          ..._items,
          ...page.items.where((e) => !codes.contains(e.code)),
        ];
        _total = page.total;
        _page++;
      });
    } catch (e) {
      if (mounted && seq == _seq) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(TicketSummary t) =>
      Navigator.pushNamed(context, AppRoutes.ticketDetail, arguments: t.code);

  void _create() => Navigator.pushNamed(context, AppRoutes.ticketCreate);

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Bantuan & Tiket',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: loggedIn
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Buat tiket',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: loggedIn ? _body() : _guestPrompt(),
    );
  }

  Widget _sellerHint() => SellerWhatsAppHint(
        key: const ValueKey('ticket-seller-hint'),
        text: 'Pertanyaan soal pesanan? Hubungi penjual lewat tombol '
            'WhatsApp di Pesanan.',
        action: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.successDark,
            side: const BorderSide(color: AppColors.success),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.orders),
          icon: const Icon(Icons.receipt_long_rounded, size: 16),
          label: const Text(
            'Buka Pesanan',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _body() {
    final hasMore = _items.length < _total;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _sellerHint(),
          const SizedBox(height: 16),
          if (_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _items.isEmpty)
            _message(
              icon: Icons.cloud_off_rounded,
              title: _error!,
              action: OutlinedButton(
                  onPressed: _load, child: const Text('Coba Lagi')),
            )
          else if (_items.isEmpty)
            _message(
              icon: Icons.support_agent_rounded,
              title: 'Belum ada tiket',
              subtitle: 'Punya kendala akun, pembayaran, atau aplikasi? '
                  'Buat tiket dan Tim KateringKita akan membalas di sini.',
            )
          else
            for (final t in _items) ...[
              _tile(t),
              const SizedBox(height: 10),
            ],
          if (hasMore && _error == null && !_loading)
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

  Widget _message({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
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

  Widget _guestPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Masuk untuk melihat tiket bantuan',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(fontSize: 16),
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

  Widget _tile(TicketSummary t) {
    final preview = t.lastMessagePreview.isEmpty
        ? null
        : '${t.lastSenderRole == 'admin' ? kTicketAdminName : 'Kamu'}: '
            '${t.lastMessagePreview}';
    return InkWell(
      key: ValueKey('ticket-${t.code}'),
      onTap: () => _openDetail(t),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.unread ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.unread
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.cardBorder,
            width: t.unread ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (t.unread)
                  Container(
                    key: ValueKey('ticket-unread-${t.code}'),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6, top: 5),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${t.code} · ${t.categoryLabel}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TicketStatusChip(t.status),
                const Spacer(),
                Text(
                  relativeTimeWib(t.lastMessageAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
