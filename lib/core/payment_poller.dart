// Pemantau status pembayaran: layar Pembayaran (payment_screen.dart) memakai PaymentPoller untuk
// menanyakan status pesanan ke backend berkala (lewat OrderRepository) sampai lunas, kedaluwarsa, atau batal.
import 'dart:async';

import '../data/order_repository.dart';
import '../models/order_api_model.dart';

/// Kesimpulan status pembayaran: masih menunggu, sudah dibayar, kedaluwarsa, atau dibatalkan.
enum PaymentOutcome { waiting, paid, expired, cancelled }

/// Menyimpulkan [PaymentOutcome] dari pesanan [o] menurut data server (bukan tebakan klien).
PaymentOutcome outcomeOf(OrderApiModel o) {
  // Sudah dibayar menang atas status lain.
  if (o.isPaid) return PaymentOutcome.paid;
  // Kedaluwarsa: status `expired`, atau masih `holding` tetapi sisa waktunya sudah 0 detik.
  if (o.status == 'expired' || (o.status == 'holding' && o.secondsLeft == 0)) {
    return PaymentOutcome.expired;
  }
  // Dibatalkan pembeli, penjual, atau sistem.
  if (o.status == 'cancelled') return PaymentOutcome.cancelled;
  return PaymentOutcome.waiting;
}

/// Memanggil GET /orders/:code berkala sampai status tidak lagi `waiting`.
///
/// Parameter konstruktor: repository pesanan, kode pesanan, dan [interval] jeda antarpanggilan
/// (bawaan 5 detik).
class PaymentPoller {
  PaymentPoller(
    this._repo,
    this._code, {
    this.interval = const Duration(seconds: 5),
  });

  final OrderRepository _repo;
  final String _code;
  final Duration interval;

  Timer? _timer;
  StreamController<OrderApiModel>? _ctrl;
  bool _busy = false;

  /// Memulai pemantauan dan mengembalikan stream berisi data pesanan terbaru tiap putaran.
  ///
  /// Pemantauan sebelumnya (bila ada) dihentikan dulu. Panggilan pertama baru terjadi setelah
  /// satu [interval]. Stream ditutup otomatis saat status bukan lagi `waiting`, saat [stop]
  /// dipanggil, atau saat pendengar berhenti berlangganan.
  Stream<OrderApiModel> start() {
    stop();
    final ctrl = StreamController<OrderApiModel>(onCancel: stop);
    _ctrl = ctrl;
    _timer = Timer.periodic(interval, (_) => _tick(ctrl));
    return ctrl.stream;
  }

  /// Satu putaran: ambil pesanan dari backend lalu kirim ke stream. Dilewati bila putaran
  /// sebelumnya belum selesai (_busy) atau stream sudah ditutup.
  Future<void> _tick(StreamController<OrderApiModel> ctrl) async {
    if (_busy || ctrl.isClosed) return;
    _busy = true;
    try {
      final o = await _repo.get(_code);
      if (ctrl.isClosed) return;
      ctrl.add(o);
      if (outcomeOf(o) != PaymentOutcome.waiting) stop();
    } catch (_) {
      // Gangguan jaringan sesaat: coba lagi pada putaran berikutnya.
    } finally {
      _busy = false;
    }
  }

  /// Menghentikan timer dan menutup stream. Aman dipanggil berkali-kali.
  void stop() {
    _timer?.cancel();
    _timer = null;
    final c = _ctrl;
    _ctrl = null;
    if (c != null && !c.isClosed) c.close();
  }
}
