import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/screens/orders/snap_webview_screen.dart';

void main() {
  test('isSnapFinished mendeteksi query hasil transaksi', () {
    expect(isSnapFinished('https://x.id/finish?order_id=KK-1&status_code=200&transaction_status=settlement'), isTrue);
    expect(isSnapFinished('https://x.id/finish?transaction_status=pending'), isTrue);
    expect(isSnapFinished('https://x.id/finish?status_code=201'), isTrue);
    expect(isSnapFinished('https://app.sandbox.midtrans.com/snap/v4/redirection/abc'), isFalse);
    expect(isSnapFinished('not a url %%'), isFalse);
  });
}
