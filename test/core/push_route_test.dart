// Isi file: test pushRoute (pemetaan payload push ke rute aplikasi).
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/push_route.dart';

void main() {
  test('order_status -> Lacak Pesanan', () {
    expect(pushRoute({'type': 'order_status', 'order_code': 'KK-1'}),
        '/order-tracking/KK-1');
  });
  test('chat_message -> Chat pesanan', () {
    expect(pushRoute({'type': 'chat_message', 'order_code': 'KK-1'}),
        '/order-chat/KK-1');
  });
  test('tipe lain atau order_code kosong -> null', () {
    expect(pushRoute({'type': 'promo'}), isNull);
    expect(pushRoute({'type': 'order_status'}), isNull);
    expect(pushRoute({'type': 'chat_message', 'order_code': ''}), isNull);
  });
}
