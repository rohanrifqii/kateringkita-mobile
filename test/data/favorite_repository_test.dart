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
}
