// Test logika langkah Lacak Pesanan: label, keadaan, dan jam tiap langkah
// dihitung dari status pesanan dan `timeline` dari server.
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/order_steps.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';

/// Pesanan minimal dengan [status], [paymentStatus], dan isi `timeline`.
OrderApiModel buildOrder(
  String status, {
  String paymentStatus = 'paid',
  Map<String, String?> timeline = const {},
}) => OrderApiModel.fromJson({
  'code': 'KK-1',
  'status': status,
  'payment_method': 'va',
  'payment_status': paymentStatus,
  'pickup_point': {'id': 1, 'name': 'Gerbang'},
  'items': [],
  'subtotal': 0,
  'discount': 0,
  'service_fee': 0,
  'total': 0,
  'created_at': '2026-11-24T02:00:00Z',
  'updated_at': '2026-11-24T02:30:00Z',
  'merchant': {'id': 1, 'business_name': 'Dapur A'},
  'timeline': timeline,
});

void main() {
  test('cooking: Diterima selesai, Dimasak sedang berjalan', () {
    final steps = buildOrderSteps(
      buildOrder(
        'cooking',
        timeline: {
          'confirmed_at': '2026-11-24T02:05:00Z',
          'cooking_at': '2026-11-24T02:10:00Z',
        },
      ),
    );
    expect(steps.map((step) => step.label), [
      'Diterima',
      'Dimasak',
      'Siap diambil',
      'Selesai',
    ]);
    expect(steps.map((step) => step.state), [
      OrderStepState.done,
      OrderStepState.current,
      OrderStepState.upcoming,
      OrderStepState.upcoming,
    ]);
    expect(steps.first.at, DateTime.utc(2026, 11, 24, 2, 5));
    expect(steps[1].at, DateTime.utc(2026, 11, 24, 2, 10));
    expect(steps[2].at, isNull);
  });

  test('holding belum bayar: Menunggu pembayaran sedang berjalan', () {
    final steps = buildOrderSteps(
      buildOrder('holding', paymentStatus: 'unpaid'),
    );
    expect(steps.first.label, 'Menunggu pembayaran');
    expect(steps.first.state, OrderStepState.current);
    expect(
      steps.skip(1).map((step) => step.state),
      everyElement(OrderStepState.upcoming),
    );
  });

  test('holding sudah bayar: Menunggu konfirmasi', () {
    final steps = buildOrderSteps(buildOrder('holding'));
    expect(steps.first.label, 'Menunggu konfirmasi');
    expect(steps.first.state, OrderStepState.current);
  });

  test('completed: semua langkah selesai', () {
    final steps = buildOrderSteps(buildOrder('completed'));
    expect(steps.map((step) => step.state), everyElement(OrderStepState.done));
  });

  test('cancelled: langkah terakhir Dibatalkan gagal dengan jam batal', () {
    final steps = buildOrderSteps(
      buildOrder(
        'cancelled',
        timeline: {
          'confirmed_at': '2026-11-24T02:05:00Z',
          'cancelled_at': '2026-11-24T02:20:00Z',
        },
      ),
    );
    expect(steps.map((step) => step.label), ['Diterima', 'Dibatalkan']);
    expect(steps.first.state, OrderStepState.done);
    expect(steps.last.state, OrderStepState.failed);
    expect(steps.last.at, DateTime.utc(2026, 11, 24, 2, 20));
  });

  test('expired: Kedaluwarsa gagal, jam jatuh ke waktu perubahan terakhir', () {
    final steps = buildOrderSteps(buildOrder('expired'));
    expect(steps.last.label, 'Kedaluwarsa');
    expect(steps.last.state, OrderStepState.failed);
    expect(steps.last.at, DateTime.utc(2026, 11, 24, 2, 30));
  });
}
