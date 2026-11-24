import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/promo_content_repository.dart';

import '../models/voucher_test.dart' show voucherJson;

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

PromoContentRepository _repo(Object Function(http.Request) body, List<http.Request> seen) =>
    PromoContentRepository(ApiClient(
      baseUrl: 'https://x.test/api/v1',
      client: MockClient((req) async {
        seen.add(req);
        return _json(body(req));
      }),
    ));

void main() {
  test('banners: GET /banners → banner promo / toko / tanpa tujuan', () async {
    final seen = <http.Request>[];
    final r = _repo(
        (_) => {
              'data': [
                {'id': 1, 'title': 'Voucher', 'image_url': 'https://img/a.webp', 'target': 'promo', 'promo': voucherJson(id: 7), 'merchant': null},
                {
                  'id': 2,
                  'title': 'Dapur Siti',
                  'image_url': 'https://img/b.webp',
                  'target': 'merchant',
                  'promo': null,
                  'merchant': {'id': 3, 'slug': 'dapur-siti', 'business_name': 'Dapur Siti'},
                },
              ],
            },
        seen);
    final b = await r.banners();
    expect(seen.single.url.path, '/api/v1/banners');
    expect(b.map((x) => x.target), [BannerTarget.promo, BannerTarget.merchant]);
    expect(b.first.promo!.id, 7);
    expect(b.last.merchant!.slug, 'dapur-siti');
    expect(b.first.imageUrl, 'https://img/a.webp');
  });

  test('popup: GET /popup → pop-up atau null', () async {
    final seen = <http.Request>[];
    final ada = _repo(
        (_) => {
              'data': {'id': 4, 'title': 'Promo akhir pekan', 'image_url': 'https://img/p.webp', 'promo': voucherJson(id: 8, toko: false)},
            },
        seen);
    final p = await ada.popup();
    expect(seen.single.url.path, '/api/v1/popup');
    expect([p!.id, p.title, p.promo!.id], [4, 'Promo akhir pekan', 8]);
    expect(await _repo((_) => {'data': null}, []).popup(), isNull);
  });
}
