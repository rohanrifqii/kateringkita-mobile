import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/favorite_repository.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

FavoriteRepository _repo(MockClientHandler h) => FavoriteRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

Map<String, dynamic> _card(int id) => {
      'id': id,
      'name': 'Lumpia $id',
      'price': 5000,
      'merchant': {
        'id': 1,
        'slug': 'toko',
        'business_name': 'Toko',
        'is_open': false,
      },
      'badge': 'sold_out',
      'is_favorite': true,
    };

void main() {
  test('list: GET /me/favorites dengan page & limit, kartu + total', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(200, {
        'data': [_card(7), _card(8)],
        'meta': {'page': 2, 'limit': 50, 'total': 52},
      });
    });
    final page = await r.list(page: 2, limit: 50);
    expect(seen.method, 'GET');
    expect(seen.url.toString(),
        'https://x.test/api/v1/me/favorites?page=2&limit=50');
    expect(page.items.map((e) => e.id), [7, 8]);
    expect(page.items.first.isFavorite, isTrue);
    // Toko tutup & menu habis tetap muncul di daftar favorit.
    expect(page.items.first.merchant.isOpen, isFalse);
    expect(page.total, 52);
    expect(page.page, 2);
  });

  test('list: meta hilang -> total = jumlah item', () async {
    final r = _repo((req) async => _json(200, {'data': [_card(1)]}));
    final page = await r.list();
    expect(page.total, 1);
    expect(page.page, 1);
  });

  test('add: PUT /me/favorites/:id, 204 tanpa body', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return http.Response('', 204);
    });
    await r.add(7);
    expect(seen.method, 'PUT');
    expect(seen.url.path, '/api/v1/me/favorites/7');
  });

  test('remove: DELETE /me/favorites/:id, 204 tanpa body', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return http.Response('', 204);
    });
    await r.remove(9);
    expect(seen.method, 'DELETE');
    expect(seen.url.path, '/api/v1/me/favorites/9');
  });

  test('add: menu tidak tampil -> ApiException 404 dari server', () async {
    final r = _repo((req) async => _json(404, {
          'error': {'code': 'NOT_FOUND', 'message': 'Menu tidak ditemukan.'}
        }));
    expect(
      () => r.add(7),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 404)
          .having((e) => e.message, 'message', 'Menu tidak ditemukan.')),
    );
  });

  group('toko favorit (Dapur Favorit)', () {
    Map<String, dynamic> store(int id, {Object? fav = true}) => {
          'id': id,
          'slug': 'dapur-$id',
          'business_name': 'Dapur $id',
          'description': null,
          'logo_url': null,
          'merchant_type': {'id': 1, 'name': 'Katering'},
          'is_open': false,
          'open_time': '08:00',
          'close_time': '17:00',
          'rating_avg': 4.5,
          'rating_count': 10,
          'pickup_points': [
            {'id': 1, 'name': 'Gerbang Barat', 'description': null}
          ],
          'is_favorite': ?fav,
        };

    test('listMerchants: GET /me/favorite-merchants, kartu toko + total',
        () async {
      late Uri url;
      final r = _repo((req) async {
        url = req.url;
        return _json(200, {
          'data': [store(3), store(4)],
          'meta': {'page': 1, 'limit': 50, 'total': 2},
        });
      });
      final page = await r.listMerchants(limit: 50);
      expect(url.path, '/api/v1/me/favorite-merchants');
      expect(url.queryParameters, {'page': '1', 'limit': '50'});
      expect(page.items.map((m) => m.slug), ['dapur-3', 'dapur-4']);
      expect(page.items.first.isFavorite, isTrue);
      expect(page.items.first.isOpen, isFalse);
      expect(page.items.first.pickupPoints.single.name, 'Gerbang Barat');
      expect(page.total, 2);
    });

    test('addMerchant/removeMerchant: PUT/DELETE, 204', () async {
      final seen = <http.Request>[];
      final r = _repo((req) async {
        seen.add(req);
        return http.Response('', 204);
      });
      await r.addMerchant(3);
      await r.removeMerchant(3);
      expect(seen.map((s) => '${s.method} ${s.url.path}'), [
        'PUT /api/v1/me/favorite-merchants/3',
        'DELETE /api/v1/me/favorite-merchants/3',
      ]);
    });

    test('addMerchant: toko tidak ada -> 404 "Toko tidak ditemukan."',
        () async {
      final r = _repo((req) async => _json(404, {
            'error': {'code': 'NOT_FOUND', 'message': 'Toko tidak ditemukan.'}
          }));
      expect(
        () => r.addMerchant(99),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Toko tidak ditemukan.')),
      );
    });

    test('is_favorite toleran: tidak ada / null -> false', () async {
      final r = _repo((req) async => _json(200, {
            'data': [store(3, fav: null)],
          }));
      final page = await r.listMerchants();
      expect(page.items.single.isFavorite, isFalse);
    });
  });
}
