import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';

import '../models/voucher_test.dart' show voucherJson;

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  late List<http.Request> seen;
  VoucherRepository repo(Object Function(http.Request) body) {
    seen = [];
    return VoucherRepository(ApiClient(
      baseUrl: 'https://x.test/api/v1',
      client: MockClient((req) async {
        seen.add(req);
        return _json(200, body(req));
      }),
    ));
  }

  test('claim: POST /me/vouchers/:id/claim → voucher diklaim', () async {
    final r = repo((_) => {'data': voucherJson(id: 7)});
    final v = await r.claim(7);
    expect('${seen.single.method} ${seen.single.url.path}',
        'POST /api/v1/me/vouchers/7/claim');
    expect(v.claimed, isTrue);
  });

  test('mine: tanpa filter / dengan keranjang checkout', () async {
    final r = repo((_) => {
          'data': [
            voucherJson(extra: {'usable': true, 'reason': null}),
          ],
        });
    expect((await r.mine()).single.usable, isTrue);
    expect(seen.last.url.path, '/api/v1/me/vouchers');
    expect(seen.last.url.queryParameters, isEmpty);
    await r.mine(merchantId: 1, subtotal: 30000, paymentMethod: 'online');
    expect(seen.last.url.queryParameters,
        {'merchant_id': '1', 'subtotal': '30000', 'payment_method': 'online'});
  });

  test('platform: GET /vouchers/platform', () async {
    final r = repo((_) => {
          'data': [voucherJson(toko: false)],
        });
    final v = await r.platform();
    expect(seen.single.url.path, '/api/v1/vouchers/platform');
    expect(v.single.merchant, isNull);
  });
}
