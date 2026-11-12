import 'dart:async';

import '../data/order_repository.dart';
import '../models/order_api_model.dart';

enum PaymentOutcome { waiting, paid, expired, cancelled }

/// Status pembayaran menurut server (bukan tebakan klien).
PaymentOutcome outcomeOf(OrderApiModel o) {
  if (o.isPaid) return PaymentOutcome.paid;
  if (o.status == 'expired' || (o.status == 'holding' && o.secondsLeft == 0)) {
    return PaymentOutcome.expired;
  }
  if (o.status == 'cancelled') return PaymentOutcome.cancelled;
  return PaymentOutcome.waiting;
}

/// Memanggil GET /orders/:code berkala sampai status tidak lagi `waiting`.
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

  Stream<OrderApiModel> start() {
    stop();
    final ctrl = StreamController<OrderApiModel>(onCancel: stop);
    _ctrl = ctrl;
    _timer = Timer.periodic(interval, (_) => _tick(ctrl));
    return ctrl.stream;
  }

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

  void stop() {
    _timer?.cancel();
    _timer = null;
    final c = _ctrl;
    _ctrl = null;
    if (c != null && !c.isClosed) c.close();
  }
}
