import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';

Map<String, dynamic> order() => {
      'code': 'KK-123',
      'status': 'holding',
      'payment_method': 'va',
      'payment_status': 'unpaid',
      'hold_until': '2026-11-12T03:05:00.000Z',
      'seconds_left': 290,
      'pickup_point': {'id': 2, 'name': 'Gazebo'},
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Lumpia',
          'qty': 2,
          'unit_price': 25000,
          'options': [
            {'id': 1, 'name': 'Sambal', 'extra_price': 1000}
          ],
          'line_total': 52000,
        }
      ],
      'subtotal': 52000,
      'discount': 0,
      'service_fee': 1000,
      'total': 53000,
      'note': null,
      'pickup_at': null,
      'cancel_reason': null,
      'cancelled_by': null,
      'created_at': '2026-11-12T03:00:00.000Z',
      'updated_at': '2026-11-12T03:00:00.000Z',
      'merchant': {'id': 3, 'business_name': 'Diego', 'wa_number': '6281'},
      'can_cancel': true,
      'can_complete': false,
      'can_review': false,
    };

void main() {
  test('parses order without payment', () {
    final o = OrderApiModel.fromJson(order());
    expect(o.code, 'KK-123');
    expect(o.holdUntil, DateTime.utc(2026, 11, 12, 3, 5));
    expect(o.secondsLeft, 290);
    expect(o.pickupPoint.name, 'Gazebo');
    expect(o.items.single.options.single.extraPrice, 1000);
    expect(o.items.single.lineTotal, 52000);
    expect(o.total, 53000);
    expect(o.merchantName, 'Diego');
    expect(o.merchantWa, '6281');
    expect(o.canCancel, true);
    expect(o.payment, isNull);
    expect(o.pickupAt, isNull);
    expect(o.isPaid, false);
  });

  test('hold_until null', () {
    final j = order()..['hold_until'] = null;
    expect(OrderApiModel.fromJson(j).holdUntil, isNull);
  });

  test('payment with va and payment_url, paid', () {
    final j = order()
      ..['payment_status'] = 'paid'
      ..['payment'] = {
        'method': 'va',
        'status': 'pending',
        'amount': 53000,
        'va': {
          'bank': 'bca',
          'va_number': '123456',
          'expires_at': '2026-11-12T04:00:00.000Z',
        },
        'payment_url': 'https://snap/x',
      };
    final o = OrderApiModel.fromJson(j);
    expect(o.isPaid, true);
    expect(o.payment!.va!.vaNumber, '123456');
    expect(o.payment!.va!.expiresAt, DateTime.utc(2026, 11, 12, 4));
    expect(o.payment!.paymentUrl, 'https://snap/x');
    expect(o.payment!.amount, 53000);
  });

  test('payment without va', () {
    final j = order()
      ..['payment'] = {'method': 'online', 'status': 'pending', 'amount': 1};
    expect(OrderApiModel.fromJson(j).payment!.va, isNull);
    expect(OrderApiModel.fromJson(j).payment!.qris, isNull);
  });

  test('payment online dengan qris', () {
    final j = order()
      ..['payment'] = {
        'method': 'online',
        'status': 'pending',
        'amount': 1,
        'payment_url': null,
        'qris': {
          'qr_string': '000201QR',
          'qr_url': 'https://api.sandbox.midtrans.com/v2/qris/t/qr-code',
          'expires_at': '2026-11-12T04:00:00.000Z',
        },
      };
    final q = OrderApiModel.fromJson(j).payment!.qris!;
    expect(q.qrString, '000201QR');
    expect(q.qrUrl, 'https://api.sandbox.midtrans.com/v2/qris/t/qr-code');
    expect(q.expiresAt, DateTime.utc(2026, 11, 12, 4));
  });

  test('parses Quote', () {
    final q = Quote.fromJson({
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Lumpia',
          'qty': 2,
          'unit_price': 25000,
          'options': [],
          'line_total': 50000,
          'available': 3,
        }
      ],
      'subtotal': 50000,
      'discount': 0,
      'service_fee': 1000,
      'total': 51000,
      'warnings': [
        {
          'code': 'LOW_STOCK',
          'menu_id': 7,
          'available': 3,
          'message': 'Sisa 3',
        }
      ],
    });
    expect(q.total, 51000);
    expect(q.warnings.single.code, 'LOW_STOCK');
    expect(q.warnings.single.available, 3);
    expect(q.items.single.options, isEmpty);
  });
}
