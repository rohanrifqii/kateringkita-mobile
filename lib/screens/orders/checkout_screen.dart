import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/pickup_time.dart';
import '../../core/require_login.dart';
import '../../data/catalog_repository.dart';
import '../../data/order_repository.dart';
import '../../models/cart_item.dart';
import '../../models/order_api_model.dart';
import '../../models/pickup_point.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/map_service.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/payment_method_tile.dart';
import '../../widgets/primary_button.dart';
import 'pickup_point_picker_screen.dart';

/// Checkout isi keranjang: quote server, titik temu, waktu ambil,
/// metode bayar, lalu buat pesanan (dengan Idempotency-Key).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];
  static const Duration _quoteDebounce = Duration(milliseconds: 400);

  static List<PaymentMethodOption> get _paymentOptions => [
        PaymentMethodOption(
          method: PaymentMethod.online,
          code: 'QR',
          title: 'QRIS / E-Wallet',
          subtitle: 'QR tampil di aplikasi: GoPay, OVO, DANA, m-banking',
          badge: 'Cepat',
          accent: AppColors.primaryDark,
          accentBg: AppColors.primarySoft,
        ),
        PaymentMethodOption(
          method: PaymentMethod.virtualAccount,
          code: 'VA',
          title: 'Virtual Account',
          subtitle: 'BCA, BNI, BRI',
          accent: AppColors.blue,
          accentBg: AppColors.blueLight,
        ),
      ];

  PaymentMethod _payment = PaymentMethod.online;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  /// true setelah lolos requireLogin.
  bool _authorized = false;

  // Titik temu.
  List<PickupPoint> _points = const [];
  bool _pointsLoading = false;
  String? _pointsError;
  PickupPoint? _point;
  String? _pointError;

  // Waktu ambil.
  bool _asap = true;
  DateTime? _pickupAtUtc;
  String? _pickupError;

  // Quote.
  Timer? _debounce;
  int _quoteSeq = 0;
  bool _quoting = false;
  Quote? _quote;
  String? _quoteError;
  String? _promoError;

  // Galat kolom data pemesan dari server.
  String? _nameError;
  String? _phoneError;
  String? _noteError;

  // Buat pesanan.
  bool _submitting = false;
  Map<String, String> _lineErrors = const {};

  static const String _genericError = 'Terjadi kesalahan. Coba lagi.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  CartProvider get _cart => context.read<CartProvider>();

  int get _preorderDays => _cart.hasPreorder ? _cart.maxPreorderDays : 0;

  /// Pre-order wajib memilih tanggal; "Secepatnya" hanya untuk non pre-order.
  bool get _isAsap => _asap && !_cart.hasPreorder;

  // ---------- Alur ----------

  Future<void> _start() async {
    if (!mounted) return;
    final ok = await requireLogin(context);
    if (!mounted) return;
    if (!ok) {
      Navigator.pop(context);
      return;
    }
    final user = context.read<AuthProvider>().user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
    setState(() => _authorized = true);
    await _loadPoints();
  }

  Future<void> _loadPoints() async {
    final items = _cart.items;
    if (items.isEmpty) return;
    final catalog = context.read<CatalogRepository>();
    final fav = context.read<AuthProvider>().user?.favoritePickupPointId;
    setState(() {
      _pointsLoading = true;
      _pointsError = null;
    });
    try {
      final menu = await catalog.menuDetail(items.first.menu.id);
      if (!mounted) return;
      final pts = menu.merchant.pickupPoints;
      PickupPoint? pick;
      for (final p in pts) {
        if (p.id == fav) pick = p;
      }
      pick ??= pts.isEmpty ? null : pts.first;
      setState(() {
        _points = pts;
        _point ??= pick;
        _pointsLoading = false;
      });
      _scheduleQuote();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pointsLoading = false;
        _pointsError = e.message;
      });
    } catch (_) {
      // Galat tak terduga (mis. respons rusak): jangan biarkan spinner macet.
      if (!mounted) return;
      setState(() {
        _pointsLoading = false;
        _pointsError = _genericError;
      });
    }
  }

  bool get _canQuote =>
      _authorized &&
      _cart.items.isNotEmpty &&
      _point != null &&
      (!_cart.hasPreorder || _pickupAtUtc != null);

  void _scheduleQuote() {
    _debounce?.cancel();
    _quoteSeq++;
    if (!_canQuote) {
      setState(() {
        _quote = null;
        _quoting = false;
      });
      return;
    }
    setState(() => _quoting = true);
    _debounce = Timer(_quoteDebounce, _runQuote);
  }

  Future<void> _runQuote() async {
    final seq = ++_quoteSeq;
    final repo = context.read<OrderRepository>();
    try {
      final q = await repo.quote(_body());
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = q;
        _quoting = false;
        _quoteError = null;
        _promoError = null;
        _pointError = null;
        _pickupError = null;
        _nameError = null;
        _phoneError = null;
        _noteError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = null;
        _quoting = false;
        final matched = _applyFieldErrors(e);
        _quoteError = matched ? null : e.message;
      });
    } catch (_) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = null;
        _quoting = false;
        _quoteError = _genericError;
      });
    }
  }

  String? _opt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> _body() {
    final at = _pickupAtUtc;
    return {
      'items': _cart.toQuoteItems(),
      'pickup_point_id': _point?.id,
      'note': _opt(_noteController),
      'promo_code': _opt(_promoController),
      'customer_name': _opt(_nameController),
      'customer_phone': _opt(_phoneController),
      if (!_isAsap && at != null) 'pickup_at': at.toUtc().toIso8601String(),
    };
  }

  /// Memetakan `fields` galat ke baris/kolom. true bila ada yang terpetakan.
  bool _applyFieldErrors(ApiException e) {
    final items = _cart.items;
    final lines = <String, String>{};
    var matched = false;
    e.fields.forEach((k, v) {
      if (v.isEmpty) return;
      final m = RegExp(r'^items\.(\d+)(\.|$)').firstMatch(k);
      if (m != null) {
        final i = int.parse(m.group(1)!);
        if (i < items.length) {
          lines.putIfAbsent(items[i].key, () => v.first);
          matched = true;
        }
      } else if (k == 'pickup_at') {
        _pickupError = v.first;
        matched = true;
      } else if (k == 'pickup_point_id') {
        _pointError = v.first;
        matched = true;
      } else if (k == 'promo_code') {
        _promoError = v.first;
        matched = true;
      } else if (k == 'customer_name') {
        _nameError = v.first;
        matched = true;
      } else if (k == 'customer_phone') {
        _phoneError = v.first;
        matched = true;
      } else if (k == 'note') {
        _noteError = v.first;
        matched = true;
      }
    });
    _lineErrors = lines;
    return matched;
  }

  void _onCartChanged() {
    setState(() => _lineErrors = const {});
    _scheduleQuote();
  }

  void _setQty(CartItem item, int qty) {
    _cart.setQty(item.key, qty);
    _onCartChanged();
  }

  void _remove(CartItem item) {
    _cart.remove(item.key);
    _onCartChanged();
  }

  Future<void> _openPointPicker() async {
    if (_pointsLoading) return;
    if (_points.isEmpty) {
      await _loadPoints();
      return;
    }
    final result = await Navigator.push<PickupPoint>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PickupPointPickerScreen(points: _points, selectedId: _point?.id),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _point = result;
      _pointError = null;
    });
    _scheduleQuote();
  }

  void _selectAsap() {
    setState(() {
      _asap = true;
      _pickupAtUtc = null;
      _pickupError = null;
    });
    _scheduleQuote();
  }

  Future<void> _pickDateTime() async {
    final po = _preorderDays;
    final nowUtc = DateTime.now().toUtc();
    final first =
        toWibWallClock(po > 0 ? earliestPickupUtc(nowUtc, po) : nowUtc);
    final last = toWibWallClock(nowUtc.add(maxPickupAhead));
    final firstDate = DateTime(first.year, first.month, first.day);
    final lastDate = DateTime(last.year, last.month, last.day);
    if (firstDate.isAfter(lastDate)) {
      setState(() =>
          _pickupError = 'Menu pre-order harus diambil paling cepat H-$po.');
      return;
    }
    final current =
        _pickupAtUtc == null ? null : toWibWallClock(_pickupAtUtc!);
    var initialDate = current == null
        ? firstDate
        : DateTime(current.year, current.month, current.day);
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Tanggal ambil (WIB)',
    );
    if (date == null || !mounted) return;

    final nowWib = toWibWallClock(DateTime.now().toUtc());
    final isToday = date.year == nowWib.year &&
        date.month == nowWib.month &&
        date.day == nowWib.day;
    final soon = nowWib.add(const Duration(hours: 1));
    final initialTime = current != null
        ? TimeOfDay(hour: current.hour, minute: current.minute)
        : isToday
            ? TimeOfDay(hour: soon.hour, minute: soon.minute)
            : const TimeOfDay(hour: 10, minute: 0);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Jam ambil (WIB)',
    );
    if (time == null || !mounted) return;

    final utc =
        wibToUtc(date.year, date.month, date.day, time.hour, time.minute);
    final now = DateTime.now().toUtc();
    if (!isPickupAllowed(utc, now, po)) {
      setState(() {
        if (!utc.isAfter(now)) {
          _pickupError = 'Waktu ambil sudah lewat. Pilih waktu lain.';
        } else if (utc.isAfter(now.add(maxPickupAhead))) {
          _pickupError = 'Waktu ambil paling lambat 7 hari ke depan.';
        } else {
          _pickupError = 'Menu pre-order harus diambil paling cepat H-$po.';
        }
      });
      return;
    }
    setState(() {
      _asap = false;
      _pickupAtUtc = utc;
      _pickupError = null;
    });
    _scheduleQuote();
  }

  bool _canPay(CartProvider cart) =>
      _authorized &&
      cart.items.isNotEmpty &&
      _point != null &&
      _quote != null &&
      !_quoting &&
      !_submitting &&
      (!cart.hasPreorder || _pickupAtUtc != null);

  void _confirmOrder() {
    final q = _quote;
    if (q == null) return;
    AppModalDialog.showPaymentConfirmation(
      context,
      total: q.total.toDouble(),
      onConfirm: _submit,
    );
  }

  Future<void> _submit() async {
    final cart = _cart;
    final repo = context.read<OrderRepository>();
    // Satu kunci per niat checkout, disimpan di CartProvider: dipakai ulang
    // saat mengulang (mis. setelah timeout, juga setelah keluar-masuk
    // checkout), baru diganti saat isi keranjang berubah atau dikosongkan.
    final key = cart.idempotencyKey;
    final body = {..._body(), 'payment_method': _payment.apiValue};
    setState(() {
      _submitting = true;
      _lineErrors = const {};
    });
    try {
      final order = await repo.create(body, idempotencyKey: key);
      if (!mounted) return;
      cart.clear();
      Navigator.pushReplacementNamed(context, AppRoutes.payment,
          arguments: order);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _applyFieldErrors(e);
      });
      // Pesanan mungkin sudah terbuat walau respons tidak sampai.
      final uncertain = e.code == 'TIMEOUT' || e.code == 'NETWORK';
      _showSnack(uncertain
          ? '${e.message} Cek tab Pesanan sebelum mencoba lagi.'
          : e.message);
      // Stok/toko berubah: segarkan total & status bayar dari server.
      if (e.code == 'OUT_OF_STOCK' || e.code == 'MERCHANT_CLOSED') {
        _scheduleQuote();
      }
    } catch (_) {
      // Galat tak terduga (mis. respons 201 rusak): tombol pulih, kunci tetap
      // sama sehingga mengulang tidak membuat pesanan ganda.
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(_genericError);
    }
  }

  void _showSnack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Checkout', style: AppTextStyles.h3.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? _buildEmpty()
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(
                        'PESANAN · ${items.first.menu.merchant.businessName}'),
                    const SizedBox(height: 10),
                    for (var i = 0; i < items.length; i++) ...[
                      _buildItemCard(items[i], i),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    _sectionLabel('DATA PEMESAN'),
                    const SizedBox(height: 10),
                    _buildOrdererForm(cart),
                    const SizedBox(height: 22),
                    _buildPaymentHeader(),
                    const SizedBox(height: 10),
                    for (final option in _paymentOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PaymentMethodTile(
                          option: option,
                          selected: _payment == option.method,
                          onTap: () =>
                              setState(() => _payment = option.method),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (_quote != null && _quote!.warnings.isNotEmpty) ...[
                      _buildWarnings(_quote!.warnings),
                      const SizedBox(height: 10),
                    ],
                    _buildSummaryCard(cart),
                  ],
                ),
              ),
      ),
      // bottomNavigationBar (bukan bottomSheet + padding manual) agar tinggi
      // area scroll otomatis menyesuaikan tinggi tombol di semua ukuran layar.
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                      color: AppColors.cardBorder.withValues(alpha: 0.6)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Opacity(
                    opacity: _canPay(cart) || _submitting ? 1 : 0.5,
                    child: PrimaryButton(
                      text: 'Proses Pembayaran',
                      isLoading: _submitting,
                      onPressed: _canPay(cart) ? _confirmOrder : null,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ---------- Sections ----------

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  color: AppColors.primaryDark, size: 34),
            ),
            const SizedBox(height: 16),
            Text('Keranjang masih kosong',
                style: AppTextStyles.h3.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              'Yuk pilih menu dulu dari beranda.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Cari Menu',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.mainNav, (_) => false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontSize: 11,
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
    );
  }

  /// Total baris dari quote bila cocok; estimasi lokal hanya sebelum quote.
  int _lineTotal(CartItem item, int index) {
    final q = _quote;
    if (q != null &&
        index < q.items.length &&
        q.items[index].menuId == item.menu.id) {
      return q.items[index].lineTotal;
    }
    return item.estimatedLineTotal;
  }

  Widget _buildItemCard(CartItem item, int index) {
    final error = _lineErrors[item.key];
    final option = item.option;
    return Container(
      key: ValueKey('cart-line-${item.key}'),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MenuImage(
              item.menu.imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menu.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 15),
                ),
                if (option != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.extraPrice > 0
                        ? '${option.name} (+ ${AppCurrency.format(option.extraPrice)})'
                        : option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5),
                  ),
                ],
                if (item.menu.isPreorder) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Pre-order H-${item.menu.preorderDays}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  AppCurrency.format(_lineTotal(item, index)),
                  style: AppTextStyles.price.copyWith(
                    fontSize: 14,
                    fontFeatures: _tabular,
                  ),
                ),
                if (error != null) _errorText(error),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkResponse(
                onTap: _submitting ? null : () => _remove(item),
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              _buildStepper(item),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(CartItem item) {
    final minQty = item.menu.minOrderQty < 1 ? 1 : item.menu.minOrderQty;

    Widget button(String label, Color color, VoidCallback? onTap) {
      return InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: onTap == null ? AppColors.textSecondary : color,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            '-',
            AppColors.textPrimary,
            _submitting || item.qty <= minQty
                ? null
                : () => _setQty(item, item.qty - 1),
          ),
          Text('${item.qty}', style: AppTextStyles.h4.copyWith(fontSize: 14)),
          button(
            '+',
            AppColors.primary,
            _submitting ? null : () => _setQty(item, item.qty + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdererForm(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OrderField(
          label: 'Nama Lengkap',
          controller: _nameController,
          hintText: 'Nama pemesan',
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError == null) return;
            setState(() => _nameError = null);
            _scheduleQuote();
          },
        ),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Kontak Penerima',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          hintText: '08xxxxxxxxxx',
          errorText: _phoneError,
          onChanged: (_) {
            if (_phoneError == null) return;
            setState(() => _phoneError = null);
            _scheduleQuote();
          },
          trailing: Text(
            '(WhatsApp Aktif)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLocationSelectorCard(),
        if (_pointError != null) _errorText(_pointError!),
        const SizedBox(height: 12),
        _buildPickupTimeCard(cart),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Catatan Khusus',
          controller: _noteController,
          fillColor: AppColors.secondaryBg,
          lines: 2,
          hintText: 'Contoh: sambal dipisah, diambil jam istirahat',
          errorText: _noteError,
          onChanged: (_) {
            if (_noteError == null) return;
            setState(() => _noteError = null);
            _scheduleQuote();
          },
        ),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Kode Promo (opsional)',
          controller: _promoController,
          hintText: 'Masukkan kode promo',
          action: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          errorText: _promoError,
          onChanged: (_) {
            if (_promoError != null) setState(() => _promoError = null);
            _scheduleQuote();
          },
        ),
      ],
    );
  }

  Widget _buildLocationSelectorCard() {
    final point = _point;
    final String title;
    final String? subtitle;
    if (_pointsLoading) {
      title = 'Memuat titik temu…';
      subtitle = null;
    } else if (_pointsError != null) {
      title = 'Gagal memuat titik temu';
      subtitle = '$_pointsError Ketuk untuk coba lagi.';
    } else if (point == null) {
      title = _authorized && _points.isEmpty
          ? 'Toko belum punya titik temu'
          : 'Pilih Titik Temu';
      subtitle = null;
    } else {
      title = point.name;
      subtitle = point.description;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _submitting ? null : _openPointPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _pointError != null ? AppColors.danger : AppColors.cardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Titik Temu Pengambilan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buka Peta',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Peta mini sebagai latar (titik temu belum punya koordinat).
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(
                  children: [
                    IgnorePointer(
                      child: FlutterMap(
                        options: const MapOptions(
                          initialCenter: ubPickupMapCenter,
                          initialZoom: 16.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapService.osmStandardTileUrl,
                            userAgentPackageName:
                                MapService.userAgentPackageName,
                          ),
                        ],
                      ),
                    ),
                    if (point != null)
                      Positioned(
                        left: 8,
                        bottom: 6,
                        right: 8,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              point.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFE53935),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupTimeCard(CartProvider cart) {
    final preorder = cart.hasPreorder;
    final po = preorder ? cart.maxPreorderDays : 0;
    final asap = _asap && !preorder;
    final at = _pickupAtUtc;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _pickupError != null ? AppColors.danger : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waktu Pengambilan',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Secepatnya'),
                selected: asap,
                onSelected:
                    preorder || _submitting ? null : (_) => _selectAsap(),
              ),
              ChoiceChip(
                label: Text(at != null && !asap
                    ? formatWib(at)
                    : 'Pilih Tanggal & Jam'),
                selected: !asap,
                onSelected: _submitting ? null : (_) => _pickDateTime(),
              ),
            ],
          ),
          if (preorder) ...[
            const SizedBox(height: 8),
            Text(
              'Ada menu pre-order: ambil paling cepat '
              '${formatWibDate(earliestPickupUtc(DateTime.now().toUtc(), po))}.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
          if (_pickupError != null) _errorText(_pickupError!),
        ],
      ),
    );
  }

  Widget _buildPaymentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sectionLabel('METODE PEMBAYARAN'),
        _pill('Auto-Verifikasi'),
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.successDark,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildWarnings(List<QuoteWarning> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CartProvider cart) {
    final q = _quote;
    final Widget body;
    if (q != null) {
      body = Column(
        children: [
          _summaryRow('Subtotal (${cart.count} Porsi)',
              AppCurrency.format(q.subtotal)),
          if (q.discount > 0)
            _summaryRow('Diskon', '- ${AppCurrency.format(q.discount)}',
                color: AppColors.success),
          _summaryRow(
            'Biaya Layanan',
            q.serviceFee == 0 ? 'Gratis' : AppCurrency.format(q.serviceFee),
            color: q.serviceFee == 0 ? AppColors.success : null,
          ),
        ],
      );
    } else {
      final failed = _quoteError != null && !_quoting;
      final String text;
      if (_quoting || _pointsLoading || !_authorized) {
        text = 'Menghitung total…';
      } else if (failed) {
        text = _quoteError!;
      } else if (_point == null) {
        text = 'Pilih titik temu untuk menghitung total.';
      } else if (cart.hasPreorder && _pickupAtUtc == null) {
        text = 'Pilih tanggal ambil untuk menghitung total.';
      } else {
        text = 'Total belum tersedia.';
      }
      body = Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: failed ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: _scheduleQuote,
              child: const Text('Coba lagi'),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.cardBorder, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: AppTextStyles.h4.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dihitung oleh server saat checkout',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                q == null ? '–' : AppCurrency.format(q.total),
                style: AppTextStyles.price.copyWith(
                  fontSize: 18,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kolom data pemesan: label kecil di dalam kotak, border berubah saat fokus.
class _OrderField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final Widget? trailing;
  final Color? fillColor;
  final int lines;
  final String hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  const _OrderField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.trailing,
    this.fillColor,
    this.lines = 1,
    this.hintText = '',
    this.errorText,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<_OrderField> createState() => _OrderFieldState();
}

class _OrderFieldState extends State<_OrderField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final error = widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: widget.fillColor ?? AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: error != null
                    ? AppColors.danger
                    : focused
                        ? AppColors.primary
                        : AppColors.cardBorder,
                width: focused ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: widget.lines > 1
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.action,
                        textCapitalization: widget.textCapitalization,
                        onChanged: widget.onChanged,
                        minLines: widget.lines,
                        maxLines: widget.lines,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: widget.hintText,
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }
}
