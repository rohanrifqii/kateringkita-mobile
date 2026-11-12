import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/payment_poller.dart';
import '../../data/order_repository.dart';
import '../../models/order_api_model.dart';
import 'snap_webview_screen.dart';

/// Membuka halaman Snap. Dapat diganti di test.
typedef SnapOpener = Future<void> Function(BuildContext context, String url);

Future<void> _openSnapWebView(BuildContext context, String url) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => SnapWebViewScreen(url: url)));

/// Halaman pembayaran pesanan (argumen rute: [OrderApiModel]).
/// Status bayar selalu berasal dari server (polling GET /orders/:code).
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.snapOpener = _openSnapWebView});

  final SnapOpener snapOpener;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  /// Nama tampilan bank -> kode API.
  static const Map<String, String> _bankCodes = {
    'BCA': 'bca',
    'BNI': 'bni',
    'BRI': 'bri',
  };

  bool _argsLoaded = false;
  late OrderApiModel _order;
  late OrderRepository _repo;

  String _selectedBank = 'BCA';
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  PaymentPoller? _poller;
  StreamSubscription<OrderApiModel>? _pollSub;
  bool _busy = false;
  bool _refreshing = false;
  bool _successShown = false;
  bool _snapOpen = false;
  bool _serverConfirmed = false;
  OrderVa? _va;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is! OrderApiModel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _argsLoaded = true;
    _repo = context.read<OrderRepository>();
    _order = arg;
    _va = arg.payment?.va;
    _remainingSeconds = _computeRemaining(arg);
    _startWatching();
    if (_order.isPaid) _scheduleSuccess();
    // Argumen rute bisa usang: segarkan dari server segera.
    Future.microtask(_refresh);
  }

  /// Sisa waktu berpatokan pada `seconds_left` server, bukan jam perangkat.
  int _computeRemaining(OrderApiModel o) {
    final s = o.secondsLeft;
    if (s != null) return s < 0 ? 0 : s;
    final hold = o.holdUntil;
    if (hold != null) {
      final d = hold.difference(DateTime.now()).inSeconds;
      return d < 0 ? 0 : d;
    }
    return 0;
  }

  /// Argumen rute yang tampak kedaluwarsa belum dianggap final sebelum
  /// server mengonfirmasi.
  PaymentOutcome get _outcome {
    final o = outcomeOf(_order);
    if (!_serverConfirmed &&
        o == PaymentOutcome.expired &&
        _order.status == 'holding') {
      return PaymentOutcome.waiting;
    }
    return o;
  }

  void _startWatching() {
    if (_outcome != PaymentOutcome.waiting) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 0) _refresh();
      }
    });
    _poller = PaymentPoller(_repo, _order.code);
    _pollSub = _poller!.start().listen(_apply);
  }

  void _stopWatching() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollSub?.cancel();
    _pollSub = null;
    _poller?.stop();
    _poller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatching();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _argsLoaded) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final o = await _repo.get(_order.code);
      if (mounted) _apply(o);
    } catch (_) {
      // Polling berikutnya akan mencoba lagi.
    } finally {
      _refreshing = false;
    }
  }

  void _apply(OrderApiModel o) {
    if (!mounted) return;
    // Monoton: status bayar tidak boleh mundur karena respons usang.
    if (_order.isPaid) return;
    if (o.updatedAt.isBefore(_order.updatedAt)) return;
    setState(() {
      _serverConfirmed = true;
      _order = o;
      _va = o.payment?.va ?? _va;
      _remainingSeconds = _computeRemaining(o);
    });
    if (_outcome != PaymentOutcome.waiting) _stopWatching();
    if (o.isPaid) _scheduleSuccess();
  }

  void _scheduleSuccess() {
    if (_successShown || _snapOpen) return;
    _successShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPaymentSuccessSheet();
    });
  }

  String _formatTimer(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Terjadi gangguan. Coba lagi.';

  void _onApiError(Object e) {
    if (!mounted) return;
    setState(() => _error = _errorText(e));
    if (e is ApiException && e.status == 409) _refresh();
  }

  Future<void> _createVa() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await _repo.createVa(_order.code, _bankCodes[_selectedBank]!);
      if (!mounted) return;
      _apply(o);
    } catch (e) {
      _onApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payOnline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await _repo.startOnline(_order.code);
      if (!mounted) return;
      final url = o.payment?.paymentUrl;
      if (url == null || url.isEmpty) {
        setState(() => _error = 'Tautan pembayaran belum tersedia. Coba lagi.');
        return;
      }
      _snapOpen = true;
      try {
        await widget.snapOpener(context, url);
      } finally {
        _snapOpen = false;
      }
      if (!mounted) return;
      await _refresh();
      if (mounted && _order.isPaid) _scheduleSuccess();
    } catch (e) {
      _onApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin'),
        backgroundColor: AppColors.successDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goHome() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.mainNav,
    (_) => false,
  );

  void _showPaymentSuccessSheet() {
    final late = _order.status == 'expired';
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                late ? 'Pembayaran Diterima' : 'Pembayaran Berhasil',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                late
                    ? 'Pembayaran diterima, tetapi pesanan sudah kedaluwarsa. Hubungi penjual atau layanan pelanggan untuk pengembalian dana.'
                    : 'Pembayaran Anda sudah dikonfirmasi. Pesanan siap diproses penjual.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _kv('Kode Pesanan', _order.code, mono: true),
                    const SizedBox(height: 6),
                    _kv(
                      'Total Dibayar',
                      AppCurrency.format(_order.total),
                      accent: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!late) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                    ),
                    label: const Text(
                      'Kirim Rincian ke WhatsApp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.whatsappGenerator,
                        arguments: _order.code,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Indeks 1 = tab Pesanan pada MainNavigationScreen.
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.mainNav,
                      (_) => false,
                      arguments: 1,
                    );
                  },
                  child: Text(
                    'Lihat Pesanan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false, bool accent = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              v,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: accent ? FontWeight.w800 : FontWeight.w700,
                color: accent ? AppColors.primary : null,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.cardBorder),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ringkasan Pesanan', style: AppTextStyles.h4),
        const SizedBox(height: 10),
        _kv('Kode Pesanan', _order.code, mono: true),
        const Divider(height: 20),
        for (final i in _order.items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(i.menuName, style: AppTextStyles.bodyMedium),
              ),
              Text(
                '${i.qty}x  ${AppCurrency.format(i.lineTotal)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        const Divider(height: 20),
        _kv('Total Pembayaran', AppCurrency.format(_order.total), accent: true),
        const SizedBox(height: 6),
        _kv('Titik Temu', _order.pickupPoint.name),
      ],
    ),
  );

  Widget _timerCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.timer_outlined, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Selesaikan pembayaran sebelum waktu habis',
            style: AppTextStyles.bodySmall,
          ),
        ),
        if (_remainingSeconds == 0)
          Text(
            'Memeriksa status pembayaran…',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            _formatTimer(_remainingSeconds),
            style: AppTextStyles.h4.copyWith(fontFamily: 'monospace'),
          ),
      ],
    ),
  );

  Widget _vaSection() {
    final va = _va;
    if (va != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Virtual Account ${va.bank.toUpperCase()}',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    va.vaNumber,
                    style: AppTextStyles.h2.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Salin nomor',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copy(va.vaNumber, 'Nomor Virtual Account'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Jumlah: ${AppCurrency.format(_order.total)}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Transfer melalui ATM, m-banking, atau internet banking. Status diperbarui otomatis setelah pembayaran diterima.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih Bank', style: AppTextStyles.h4),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final b in _bankCodes.keys)
                ChoiceChip(
                  label: Text(b),
                  selected: _selectedBank == b,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _selectedBank = b),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _createVa,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buat Nomor Virtual Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineSection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QRIS / E-Wallet', style: AppTextStyles.h4),
        const SizedBox(height: 6),
        Text(
          'Anda akan diarahkan ke halaman pembayaran Midtrans.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _payOnline,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Bayar dengan QRIS / E-Wallet'),
          ),
        ),
      ],
    ),
  );

  Widget _endedSection() {
    final cancelled = _outcome == PaymentOutcome.cancelled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            cancelled
                ? 'Pesanan ini sudah dibatalkan.'
                : 'Batas waktu pesanan sudah habis.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goHome,
              child: const Text('Kembali ke Beranda'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsLoaded) return const Scaffold();
    final ended = !_order.isPaid && _outcome != PaymentOutcome.waiting;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Pembayaran', style: AppTextStyles.h3),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ended)
            _endedSection()
          else if (_order.isPaid)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Pembayaran sudah diterima.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          else ...[
            _timerCard(),
            const SizedBox(height: 12),
            if (_order.paymentMethod == 'va')
              _vaSection()
            else
              _onlineSection(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          _summaryCard(),
        ],
      ),
    );
  }
}
