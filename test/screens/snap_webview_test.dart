import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/screens/orders/snap_webview_screen.dart';

void main() {
  _classification();
  test('isSnapFinished mendeteksi query hasil transaksi', () {
    expect(
      isSnapFinished(
        'https://x.id/finish?order_id=KK-1&status_code=200&transaction_status=settlement',
      ),
      isTrue,
    );
    expect(
      isSnapFinished('https://x.id/finish?transaction_status=pending'),
      isTrue,
    );
    expect(isSnapFinished('https://x.id/finish?status_code=201'), isTrue);
    expect(
      isSnapFinished(
        'https://app.sandbox.midtrans.com/snap/v4/redirection/abc',
      ),
      isFalse,
    );
    expect(isSnapFinished('not a url %%'), isFalse);
  });
}

void _classification() {
  test('classifySnapUrl', () {
    expect(
      classifySnapUrl('https://app.midtrans.com/snap/x'),
      SnapUrlAction.allow,
    );
    expect(
      classifySnapUrl('https://x.id/f?transaction_status=settlement'),
      SnapUrlAction.finished,
    );
    expect(
      classifySnapUrl('gojek://gopay/merchanttransfer?x=1'),
      SnapUrlAction.external,
    );
    expect(classifySnapUrl('shopeeid://main'), SnapUrlAction.external);
    expect(
      classifySnapUrl('intent://pay#Intent;scheme=x;end'),
      SnapUrlAction.external,
    );
  });

  test('intentFallbackUrl', () {
    expect(
      intentFallbackUrl(
        'intent://pay#Intent;scheme=gojek;S.browser_fallback_url=https%3A%2F%2Fgo.jek%2Fx%3Fa%3D1;end',
      ),
      'https://go.jek/x?a=1',
    );
    expect(intentFallbackUrl('intent://pay#Intent;scheme=gojek;end'), isNull);
    expect(intentFallbackUrl('gojek://x'), isNull);
    expect(
      intentFallbackUrl(
        'intent://p#Intent;S.browser_fallback_url=javascript%3Aalert(1);end',
      ),
      isNull,
    );
  });
}
