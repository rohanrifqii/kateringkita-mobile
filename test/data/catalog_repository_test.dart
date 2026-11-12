import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

CatalogRepository _repo(MockClientHandler h) => CatalogRepository(ApiClient(
    client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

Map<String, dynamic> _card(int id) => {
      'id': id,
      'name': 'Lumpia',
      'price': 5000,
      'merchant': {
        'id': 1,
        'slug': 'toko',
        'business_name': 'Toko',
        'is_open': true,
      },
    };

void main() {
  test('menus builds query string with defaults', () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {
        'data': [_card(1)],
        'meta': {'page': 1, 'limit': 20, 'total': 7}
      });
    });
    final page =
        await r.menus(q: 'lumpia', category: 'danusan', sort: 'price_asc');
    expect(url.toString(),
        'https://x.test/api/v1/menus?q=lumpia&category=danusan&sort=price_asc&page=1&limit=20');
    expect(page.items.length, 1);
    expect(page.total, 7);
    expect(page.page, 1);
  });

  test('menus omits null params', () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {'data': [], 'meta': {'page': 1, 'limit': 20, 'total': 0}});
    });
    await r.menus();
    expect(url.queryParameters.keys.toSet(), {'sort', 'page', 'limit'});
  });

  test('categories cached after first call', () async {
    var n = 0;
    final r = _repo((req) async {
      n++;
      return _json(200, {
        'data': [
          {'id': 1, 'name': 'A', 'slug': 'a', 'icon': 'x'}
        ]
      });
    });
    await r.categories();
    final c = await r.categories();
    expect(n, 1);
    expect(c.first.slug, 'a');
  });

  test('pickupPoints cached', () async {
    var n = 0;
    final r = _repo((req) async {
      n++;
      return _json(200, {
        'data': [
          {'id': 1, 'name': 'Kantin'}
        ]
      });
    });
    await r.pickupPoints();
    final p = await r.pickupPoints();
    expect(n, 1);
    expect(p.first.name, 'Kantin');
  });

  test('menuDetail 404 throws ApiException', () async {
    final r = _repo((req) async => _json(404, {
          'error': {'code': 'NOT_FOUND', 'message': 'Menu tidak ditemukan.'}
        }));
    expect(
        r.menuDetail(9),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Menu tidak ditemukan.')));
  });

  test('menuDetail parses', () async {
    final r = _repo((req) async {
      expect(req.url.path, '/api/v1/menus/3');
      return _json(200, {'data': _card(3)});
    });
    expect((await r.menuDetail(3)).id, 3);
  });

  test('reviews parses', () async {
    final r = _repo((req) async {
      expect(req.url.toString(), 'https://x.test/api/v1/menus/3/reviews?page=2');
      return _json(200, {
        'data': [
          {
            'rating': 5,
            'comment': null,
            'customer_name': 'Budi',
            'created_at': '2026-01-02T03:04:05.000Z'
          }
        ]
      });
    });
    final l = await r.reviews(3, page: 2);
    expect(l.first.rating, 5);
    expect(l.first.comment, isNull);
    expect(l.first.customerName, 'Budi');
    expect(l.first.createdAt.year, 2026);
  });

  test('reviews dengan limit (halamanSchema backend, maks 100)', () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {'data': []});
    });
    await r.reviews(3, limit: 5);
    expect(url.queryParameters, {'page': '1', 'limit': '5'});
  });

  test('merchant parses with int rating_avg', () async {
    final r = _repo((req) async {
      expect(req.url.path, '/api/v1/merchants/toko');
      return _json(200, {
        'data': {
          'id': 1,
          'slug': 'toko',
          'business_name': 'Toko',
          'merchant_type': {'id': 2, 'name': 'Kantin'},
          'is_open': false,
          'open_time': '08:00',
          'close_time': '17:00',
          'rating_avg': 4,
          'rating_count': 3,
          'pickup_points': [
            {'id': 1, 'name': 'Gerbang'}
          ]
        }
      });
    });
    final m = await r.merchant('toko');
    expect(m.businessName, 'Toko');
    expect(m.merchantTypeName, 'Kantin');
    expect(m.ratingAvg, 4.0);
    expect(m.isOpen, false);
    expect(m.pickupPoints.single.name, 'Gerbang');
    expect(m.description, isNull);
  });
}
