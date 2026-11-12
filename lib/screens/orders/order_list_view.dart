import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/require_login.dart';
import '../../data/catalog_repository.dart';
import '../../data/order_repository.dart';
import '../../models/order_api_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/order_status_label.dart';
import '../../widgets/review_sheet.dart';

/// Daftar pesanan satu tab (`active` | `completed` | `cancelled`) dari server,
/// lengkap dengan aksi batal / selesai / bayar / pesan lagi.
///
/// Polling 15 dtk hanya berjalan saat layar terlihat: tab IndexedStack yang
/// tersembunyi (TickerMode mati), rute lain di atasnya, atau aplikasi di
/// latar belakang tidak memicu request. Timer dibatalkan di dispose.
class OrderListView extends StatefulWidget {
  const OrderListView({super.key, required this.tab, this.query = ''});

  final String tab;
  final String query;

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView>
    with WidgetsBindingObserver {
  List<OrderApiModel> _orders = const [];
  bool _loading = true;
  String? _error;
  bool _fetching = false;
  int _seq = 0;
  bool _foreground = true;
  bool _visible = true;
  bool _wasVisible = true;
  Timer? _timer;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _visible = TickerMode.valuesOf(context).enabled && (route?.isCurrent ?? true);
    if (_visible && !_wasVisible && !_loading) _poll();
    _wasVisible = _visible;
  }

  @override
  void didUpdateWidget(covariant OrderListView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query || old.tab != widget.tab) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _visible) _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _loggedIn => context.read<AuthProvider>().isLoggedIn;

  void _poll() {
    if (!mounted || !_foreground || !_visible || !_loggedIn || _fetching) {
      return;
    }
    _load(silent: true);
  }

  /// Setiap pemuatan mengambil nomor urut; hasil dari permintaan yang lebih
  /// lama (mis. query sudah berganti) diabaikan.
  Future<void> _load({bool silent = false}) async {
    if (!mounted || !_loggedIn) return;
    final seq = ++_seq;
    _fetching = true;
    if (!silent) setState(() => _loading = true);
    try {
      final res = await context
          .read<OrderRepository>()
          .list(tab: widget.tab, q: widget.query);
      if (!mounted || seq != _seq) return;
      setState(() {
        _orders = res.items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        if (!silent || _orders.isEmpty) _error = _msg(e);
        _loading = false;
      });
    } finally {
      if (seq == _seq) _fetching = false;
    }
  }

  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(OrderApiModel o, Future<void> Function() action) async {
    if (_busy.contains(o.code)) return;
    setState(() => _busy.add(o.code));
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(o.code));
    }
  }

  Future<bool> _confirm(String title, String body, String no, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _cancel(OrderApiModel o) async {
    if (!await _confirm('Batalkan pesanan?',
        'Pesanan ini akan dibatalkan dan tidak bisa dikembalikan.',
        'Tidak', 'Ya, Batalkan')) {
      return;
    }
    await _run(o, () async {
      await context.read<OrderRepository>().cancel(o.code);
      if (!mounted) return;
      _snack('Pesanan ${o.code} telah dibatalkan.');
      await _load(silent: true);
    });
  }

  Future<void> _complete(OrderApiModel o) async {
    if (!await _confirm('Pesanan sudah diambil?',
        'Pesanan akan ditandai selesai.', 'Belum', 'Sudah')) {
      return;
    }
    await _run(o, () async {
      await context.read<OrderRepository>().complete(o.code);
      if (!mounted) return;
      _snack('Pesanan ${o.code} selesai! Terima kasih.');
      await _load(silent: true);
    });
  }

  Future<void> _review(OrderApiModel o) async {
    final ok = await showReviewSheet(context, o);
    if (ok == true && mounted) {
      _snack('Terima kasih atas ulasanmu!');
      await _load(silent: true);
    }
  }

  Future<void> _pay(OrderApiModel o) => _run(o, () async {
        final full = await context.read<OrderRepository>().get(o.code);
        if (!mounted) return;
        await Navigator.pushNamed(context, AppRoutes.payment, arguments: full);
        if (mounted) _load(silent: true);
      });

  static const _unavailable =
      'Beberapa pilihan menu sudah tidak tersedia. Silakan pesan ulang dari halaman menu.';

  Future<void> _reorder(OrderApiModel o) => _run(o, () async {
        final orders = context.read<OrderRepository>();
        final catalog = context.read<CatalogRepository>();
        final cart = context.read<CartProvider>();
        final res = await orders.reorder(o.code);
        final lines = ((res.request['items'] as List?) ?? const []).cast<Map>();
        if (lines.isEmpty) {
          _snack(_unavailable);
          return;
        }
        // Ambil & validasi semua menu dulu; keranjang baru diganti bila semua
        // berhasil.
        final resolved = <(ProductModel, MenuOption?, int)>[];
        for (final l in lines) {
          final menu = await catalog.menuDetail((l['menu_id'] as num).toInt());
          final ids = ((l['option_ids'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList();
          final opts = menu.options.where((x) => ids.contains(x.id)).toList();
          if (!menu.canOrder || opts.length != ids.length || ids.length > 1) {
            if (mounted) _snack(_unavailable);
            return;
          }
          resolved.add(
              (menu, opts.isEmpty ? null : opts.first, (l['qty'] as num).toInt()));
        }
        if (!mounted) return;
        for (var i = 0; i < resolved.length; i++) {
          final (menu, opt, qty) = resolved[i];
          if (i == 0) {
            cart.replaceWith(menu, option: opt, qty: qty);
          } else {
            cart.add(menu, option: opt, qty: qty);
          }
        }
        await Navigator.pushNamed(context, AppRoutes.checkout);
      });

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (!loggedIn) return _guestPrompt();
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty) {
      return _scrollable(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!,
              textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
        ],
      ));
    }
    if (_orders.isEmpty) return _scrollable(_emptyState());
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _card(_orders[i]),
      ),
    );
  }

  Widget _scrollable(Widget child) => RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(32), child: child)),
            ),
          ),
        ),
      );

  Widget _guestPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Masuk untuk melihat pesananmu',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (await requireLogin(context)) _load();
                },
                child: const Text('Masuk'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyState() {
    final message = switch (widget.tab) {
      'active' => 'Belum ada pesanan aktif.',
      'completed' => 'Belum ada pesanan yang selesai.',
      _ => 'Belum ada pesanan yang dibatalkan.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.primarySoft, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded,
              size: 38, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(message, style: AppTextStyles.h3.copyWith(fontSize: 16)),
        const SizedBox(height: 18),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.mainNav, (r) => false),
          child: const Text('Jelajahi Menu Katering'),
        ),
      ],
    );
  }

  String _countdown(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Widget _badge(OrderApiModel o) {
    final (bg, fg) = switch (o.status) {
      'completed' => (AppColors.successLight, AppColors.successDark),
      'cancelled' || 'expired' => (AppColors.dangerLight, AppColors.danger),
      _ => (AppColors.primarySoft, AppColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(orderStatusLabel(o),
          style: AppTextStyles.bodySmall
              .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  Widget _card(OrderApiModel o) {
    final first = o.items.isEmpty ? null : o.items.first;
    final more = o.items.length - 1;
    final title = first == null
        ? o.merchantName
        : more > 0
            ? '${first.menuName} +$more menu lain'
            : first.menuName;
    final isOpen = o.status != 'completed' &&
        o.status != 'cancelled' &&
        o.status != 'expired';
    final holding = o.status == 'holding' && !o.isPaid;
    final busy = _busy.contains(o.code);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(o.code,
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              _badge(o),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const MenuImage(null,
                    width: 60, height: 60, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h4.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Total ${AppCurrency.format(o.total)}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary, fontSize: 12)),
                    if (holding && o.secondsLeft != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: AppColors.primaryDark),
                        const SizedBox(width: 4),
                        Text('Sisa waktu: ${_countdown(o.secondsLeft!)}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              if (holding)
                _filled('Lanjutkan Bayar', AppColors.primary,
                    busy ? null : () => _pay(o)),
              if (isOpen && !holding)
                _filled('Buka WhatsApp', AppColors.success, () {
                  Navigator.pushNamed(context, AppRoutes.whatsappGenerator,
                      arguments: o.code);
                }),
              if (!isOpen)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: busy ? null : () => _reorder(o),
                  child: Text('Pesan Lagi',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ),
              if (o.canReview)
                _filled('Beri Ulasan', AppColors.primary,
                    busy ? null : () => _review(o)),
            ],
          ),
          if (o.canCancel || o.canComplete) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (o.canCancel)
                  TextButton(
                    style: _textBtn,
                    onPressed: busy ? null : () => _cancel(o),
                    child: Text('Batalkan',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                if (o.canCancel && o.canComplete) const SizedBox(width: 12),
                if (o.canComplete)
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: AppColors.primary),
                    label: Text('Selesaikan Pesanan',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    style: _textBtn,
                    onPressed: busy ? null : () => _complete(o),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle get _textBtn => TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  Widget _filled(String text, Color color, VoidCallback? onTap) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      );
}
