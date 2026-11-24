// Layar pembayaran pesanan (alamat /payment/<kode>), dibuka dari checkout (setelah POST /orders) atau tombol
// "Lanjutkan Bayar" di daftar pesanan; saat halaman web dimuat ulang, pesanan dimuat lagi dari kode di alamat. Bayar lewat Virtual Account (POST /orders/:code/va), QRIS yang QR-nya digambar langsung di layar ini
// (POST /orders/:code/qris), atau cadangan halaman Snap Midtrans (POST /orders/:code/online lalu SnapWebViewScreen).
// Status bayar selalu dibaca dari server.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/clipboard_copy.dart';
import '../../core/payment_poller.dart';
import '../../data/order_repository.dart';
import '../../models/order_api_model.dart';
import 'snap_webview_screen.dart';

/// Membuka halaman Snap. Dapat diganti di test.
typedef SnapOpener = Future<void> Function(BuildContext context, String url);

// Pembuka Snap bawaan: dorong SnapWebViewScreen dan tunggu sampai ditutup.
Future<void> _openSnapWebView(BuildContext context, String url) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => SnapWebViewScreen(url: url)));

/// Membuka tautan di luar aplikasi (browser / tab baru). Dapat diganti di test.
typedef LinkOpener = Future<void> Function(String url);

// Pembuka tautan bawaan: buka di aplikasi/browser luar; StateError bila tautan tidak bisa dibuka.
Future<void> _openExternal(String url) async {
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
    throw StateError('tautan tidak terbuka');
  }
}

/// Halaman pembayaran pesanan. Pesanan diambil dari argumen rute ([OrderApiModel]) bila ada;
/// bila tidak (mis. halaman web dimuat ulang di `/payment/<kode>`), pesanan [orderCode]
/// dimuat dari server (GET /orders/:code).
/// Status bayar selalu berasal dari server (polling GET /orders/:code).
/// Pesanan `online`: QRIS dibuat otomatis dan QR-nya digambar di aplikasi;
/// halaman Snap Midtrans hanya cadangan selama QR belum ada.
/// Tanpa argumen [OrderApiModel] dan tanpa [orderCode], layar langsung ditutup.
/// [snapOpener] membuka halaman Snap (bawaannya WebView) dan [linkOpener] membuka gambar QR di luar aplikasi;
/// keduanya bisa diganti di test.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    this.orderCode,
    this.snapOpener = _openSnapWebView,
    this.linkOpener = _openExternal,
  });

  /// Kode pesanan dari alamat `/payment/<kode>`; dipakai bila argumen rute tidak membawa pesanan.
  final String? orderCode;
  final SnapOpener snapOpener;
  final LinkOpener linkOpener;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  // Nama tampilan bank -> kode API.
  static const Map<String, String> _bankCodes = {
    'BCA': 'bca',
    'BNI': 'bni',
    'BRI': 'bri',
  };

  // True setelah pesanan tersedia (dari argumen rute atau dari server).
  bool _orderLoaded = false;
  // True selama pesanan [PaymentScreen.orderCode] dimuat dari server.
  bool _loadingOrder = false;
  late OrderApiModel _order;
  late OrderRepository _repo;

  // Bank terpilih untuk Virtual Account (nama tampilan, kunci [_bankCodes]).
  String _selectedBank = 'BCA';
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  PaymentPoller? _poller;
  StreamSubscription<OrderApiModel>? _pollSub;
  bool _busy = false;
  bool _refreshing = false;
  // Lembar sukses hanya muncul sekali.
  bool _successShown = false;
  // Selama WebView Snap terbuka, lembar sukses ditunda sampai layar kembali.
  bool _snapOpen = false;
  // True setelah ada data dari server (bukan hanya argumen rute).
  bool _serverConfirmed = false;
  OrderVa? _va;
  OrderQris? _qris;
  bool _qrisTried = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 1. Pesanan disiapkan sekali saja.
    if (_orderLoaded || _loadingOrder) return;
    _repo = context.read<OrderRepository>();
    final argument = ModalRoute.of(context)?.settings.arguments;
    // 2. Pesanan dari argumen rute: langsung tampil, lalu disegarkan dari server.
    if (argument is OrderApiModel) {
      _startWith(argument, fromServer: false);
      return;
    }
    // 3. Hanya ada kode di alamat (mis. halaman web dimuat ulang): muat dari server.
    if (widget.orderCode != null) {
      _loadingOrder = true;
      _loadOrderByCode();
      return;
    }
    // 4. Tidak ada pesanan sama sekali: tutup layar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  /// Memuat pesanan [PaymentScreen.orderCode] dari server (GET /orders/:code) lalu
  /// menampilkannya; bila gagal, layar menampilkan pesan dan tombol coba lagi.
  /// Pemanggil menyetel [_loadingOrder] lebih dulu.
  Future<void> _loadOrderByCode() async {
    try {
      final order = await _repo.get(widget.orderCode!);
      if (!mounted) return;
      setState(() {
        _loadingOrder = false;
        _startWith(order, fromServer: true);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOrder = false;
        _error = _errorText(error);
      });
    }
  }

  /// Menampilkan [order] lalu mulai hitung mundur dan polling status bayar.
  ///
  /// @param order pesanan yang dibayar.
  /// @param fromServer true bila [order] baru saja diambil dari server, jadi
  ///   tidak perlu disegarkan lagi sebelum QRIS disiapkan.
  void _startWith(OrderApiModel order, {required bool fromServer}) {
    _orderLoaded = true;
    _serverConfirmed = fromServer;
    _order = order;
    _va = order.payment?.va;
    _qris = order.payment?.qris;
    _remainingSeconds = _computeRemaining(order);
    _startWatching();
    if (_order.isPaid) _scheduleSuccess();
    // Argumen rute bisa usang: segarkan dari server segera, lalu siapkan QRIS.
    Future.microtask(() async {
      if (!fromServer) await _refresh();
      _autoQris();
    });
  }

  // QRIS dibuat sekali secara otomatis untuk pesanan online yang menunggu
  // bayar. Tidak bila halaman Snap sudah pernah dibuka: pembeli mungkin
  // sudah memilih metode di sana (order_id Midtrans sudah terpakai).
  void _autoQris() {
    if (!mounted || _qrisTried || _qris != null) return;
    if (_order.paymentMethod != 'online' || _order.isPaid) return;
    if (_outcome != PaymentOutcome.waiting) return;
    final snap = _order.payment?.paymentUrl;
    if (snap != null && snap.isNotEmpty) return;
    _createQris();
  }

  // Sisa waktu berpatokan pada `seconds_left` server, bukan jam perangkat.
  // Jam perangkat hanya dipakai bila server tidak mengirim `seconds_left`
  // (selisih ke `hold_until`); tidak pernah negatif.
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

  // Argumen rute yang tampak kedaluwarsa belum dianggap final sebelum
  // server mengonfirmasi.
  PaymentOutcome get _outcome {
    final o = outcomeOf(_order);
    if (!_serverConfirmed &&
        o == PaymentOutcome.expired &&
        _order.status == 'holding') {
      return PaymentOutcome.waiting;
    }
    return o;
  }

  // Selama status masih menunggu: hitung mundur tiap detik (saat habis,
  // tanya server) dan polling status lewat [PaymentPoller].
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

  // Hentikan timer hitung mundur dan polling.
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
    // Kembali dari aplikasi bank/e-wallet: cek status segera.
    if (state == AppLifecycleState.resumed && _orderLoaded) _refresh();
  }

  // Ambil status terbaru (GET /orders/:code) sekali; panggilan yang tumpang
  // tindih diabaikan dan galat didiamkan.
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

  // Terapkan data pesanan dari server ke layar; hentikan pemantauan bila
  // status sudah final dan tampilkan lembar sukses bila sudah dibayar.
  void _apply(OrderApiModel o) {
    if (!mounted) return;
    // Monoton: status bayar tidak boleh mundur karena respons usang.
    if (_order.isPaid) return;
    if (o.updatedAt.isBefore(_order.updatedAt)) return;
    setState(() {
      _serverConfirmed = true;
      _order = o;
      _va = o.payment?.va ?? _va;
      _qris = o.payment?.qris ?? _qris;
      _remainingSeconds = _computeRemaining(o);
    });
    if (_outcome != PaymentOutcome.waiting) _stopWatching();
    if (o.isPaid) _scheduleSuccess();
  }

  // Jadwalkan lembar sukses setelah frame ini (sekali saja, tidak saat Snap
  // masih terbuka).
  void _scheduleSuccess() {
    if (_successShown || _snapOpen) return;
    _successShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPaymentSuccessSheet();
    });
  }

  // Mengubah detik menjadi teks jj:mm:dd.
  String _formatTimer(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Terjadi gangguan. Coba lagi.';

  // Tampilkan galat; 409 (konflik dengan keadaan pesanan di server) memicu
  // penyegaran status.
  void _onApiError(Object e) {
    if (!mounted) return;
    setState(() => _error = _errorText(e));
    if (e is ApiException && e.status == 409) _refresh();
  }

  // Minta nomor Virtual Account untuk bank terpilih (POST /orders/:code/va).
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

  // Minta server membuat transaksi QRIS (POST /orders/:code/qris) lalu terapkan pesanan terbaru yang membawa data QR.
  // Ditandai sudah dicoba agar pembuatan otomatis tidak diulang; galat tampil lewat [_onApiError].
  Future<void> _createQris() async {
    _qrisTried = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await _repo.startQris(_order.code);
      if (!mounted) return;
      _apply(o);
    } catch (e) {
      _onApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Buka gambar QR dari server di luar aplikasi (agar bisa disimpan lalu diunggah ke aplikasi pembayaran);
  // bila gagal, SnackBar menyarankan screenshot layar.
  Future<void> _openQrImage(String url) async {
    try {
      await widget.linkOpener(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gambar QR tidak bisa dibuka. Screenshot QR di layar ini.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Cadangan bayar lewat halaman Snap Midtrans: siapkan tautan Snap (POST /orders/:code/online bila belum ada),
  // buka WebView, lalu cek status ke server setelah ditutup.
  Future<void> _payOnline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Tautan Snap yang sudah ada dipakai lagi; transaksi baru hanya dibuat
      // bila belum ada tautan.
      var url = _order.payment?.paymentUrl;
      if (url == null || url.isEmpty) {
        final o = await _repo.startOnline(_order.code);
        if (!mounted) return;
        _apply(o);
        if (_order.isPaid) return;
        url = o.payment?.paymentUrl;
      }
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

  // Salin [text] (mis. nomor VA) lewat [copyText]; SnackBar hijau bila berhasil, merah dengan saran catat manual bila gagal.
  Future<void> _copy(String text, String label) async {
    final ok = await copyText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '$label berhasil disalin'
            : 'Gagal menyalin. Catat $label secara manual.'),
        backgroundColor: ok ? AppColors.successDark : AppColors.danger,
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

  // Lembar sukses (tidak bisa ditutup dengan geser). Bila uang masuk setelah
  // pesanan kedaluwarsa, tampil pesan pengembalian dana tanpa tombol WhatsApp.
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

  // Bagian VA: nomor VA bila sudah dibuat, selain itu pilihan bank + tombol
  // buat nomor.
  Widget _vaSection() {
    final va = _va;
    // Nomor VA sudah dibuat server: kartu nomor rekening VA + tombol salin.
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
          // Pilihan bank; tidak bisa diganti selama permintaan masih berjalan.
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

  // Bagian pembayaran online: kartu QR bila QRIS sudah ada; selain itu tombol "Tampilkan QRIS" dan tombol cadangan
  // halaman Midtrans.
  Widget _onlineSection() {
    final q = _qris;
    if (q != null) return _qrisCard(q);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QRIS', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            'Kode QR pembayaran tampil di halaman ini. Scan dengan aplikasi e-wallet atau m-banking.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _createQris,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tampilkan QRIS'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _payOnline,
              child: const Text('Bayar lewat halaman Midtrans'),
            ),
          ),
          Text(
            'Halaman Midtrans: GoPay, ShopeePay, atau Virtual Account.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // Kartu QRIS: QR digambar dari `qrString` server, petunjuk bayar dari HP yang sama, dan tombol membuka gambar QR.
  Widget _qrisCard(OrderQris q) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scan QRIS', style: AppTextStyles.h4),
        const SizedBox(height: 6),
        Text(
          'Bayar ${AppCurrency.format(_order.total)} dengan GoPay, OVO, DANA, ShopeePay, LinkAja, atau m-banking.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        // Kotak QR: digambar dari `qrString` server.
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // QR selalu di latar putih agar terbaca pemindai, juga di tema gelap.
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: QrImageView(
              key: ValueKey('qris:${q.qrString}'),
              data: q.qrString,
              size: 220,
              backgroundColor: Colors.white,
              semanticsLabel: 'Kode QRIS pembayaran',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Membayar dari HP ini? Buka gambar QR lalu simpan (atau screenshot layar ini), kemudian pilih unggah dari galeri di menu scan aplikasi pembayaran.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Buka Gambar QR'),
          onPressed: () => _openQrImage(q.qrUrl),
        ),
        const SizedBox(height: 8),
        Text(
          'Status diperbarui otomatis setelah pembayaran diterima.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );

  // Pesanan dibatalkan atau kedaluwarsa tanpa pembayaran.
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

  // Layar sebelum pesanan tersedia: memuat, atau pesan galat dengan tombol coba lagi.
  Widget _loadingScaffold() {
    final error = _error;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Pembayaran', style: AppTextStyles.h3),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _loadingOrder = true;
                          _error = null;
                        });
                        _loadOrderByCode();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_orderLoaded) return _loadingScaffold();
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
            // Metode bayar sudah dipilih saat checkout.
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
