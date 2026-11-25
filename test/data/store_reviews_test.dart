import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/store_reviews.dart';
import 'package:kateringkita_pbl/models/product_model.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

ProductModel _menu(int id, int ratingCount) => ProductModel(
      id: id,
      name: 'Menu $id',
      price: 1000,
      ratingCount: ratingCount,
      merchant: const MerchantRef(
          id: 1, slug: 'dapur-a', businessName: 'Dapur A', isOpen: true),
    );

Map<String, dynamic> _review(String who, String at, {int rating = 5}) => {
      'rating': rating,
      'comment': 'Ulasan $who',
      'customer_name': '$who***',
      'created_at': at,
    };

void main() {
  group('pickReviewedMenus', () {
    test('hanya menu berulasan, terbanyak dulu, dibatasi', () {
      final menus = [
        _menu(1, 0),
        _menu(2, 5),
        _menu(3, 12),
        _menu(4, 5),
        _menu(5, 1),
      ];
      expect(pickReviewedMenus(menus, max: 3).map((m) => m.id), [3, 2, 4]);
      expect(pickReviewedMenus([_menu(1, 0)]), isEmpty);
    });
  });

  group('loadStoreReviews', () {
    test('gabung & urut terbaru; maks 10 menu x 5 ulasan per request',
        () async {
      final seen = <Uri>[];
      final repo = CatalogRepository(ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async {
          seen.add(req.url);
          final id = req.url.pathSegments[req.url.pathSegments.length - 2];
          if (id == '2') {
            return _json({
              'data': [
                _review('An', '2026-11-12T05:00:00Z'),
                _review('Bu', '2026-11-01T05:00:00Z', rating: 4),
              ],
              'meta': {'page': 1, 'limit': 5, 'total': 9}
            });
          }
          return _json({
            'data': [_review('Ci', '2026-11-10T05:00:00Z', rating: 3)],
            'meta': {'page': 1, 'limit': 5, 'total': 1}
          });
        }),
      ));
      final menus = [
        for (var i = 1; i <= 12; i++) _menu(i, i == 2 ? 50 : 13 - i),
      ];
      final r = await loadStoreReviews(repo, menus);

      expect(seen, hasLength(10));
      expect(seen.every((u) => u.queryParameters['limit'] == '5'), isTrue);
      expect(seen.every((u) => u.queryParameters['page'] == '1'), isTrue);
      expect(seen.any((u) => u.path.endsWith('/menus/12/reviews')), isFalse);
      expect(r.failed, 0);
      expect(r.reviews.first.review.customerName, 'An***');
      expect(r.reviews.first.menuName, 'Menu 2');
      expect(r.reviews[1].review.customerName, 'Ci***');
      expect(r.reviews.last.review.customerName, 'Bu***');
      expect(
          r.reviews
              .map((e) => e.review.createdAt)
              .toList(),
          isA<List<DateTime>>().having(
              (l) => [for (var i = 1; i < l.length; i++) !l[i].isAfter(l[i - 1])]
                  .every((ok) => ok),
              'terurut turun',
              isTrue));
    });

    test('tanpa menu berulasan: tanpa request, hasil kosong', () async {
      var calls = 0;
      final repo = CatalogRepository(ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async {
          calls++;
          return _json({'data': []});
        }),
      ));
      final r = await loadStoreReviews(repo, [_menu(1, 0), _menu(2, 0)]);
      expect(calls, 0);
      expect(r.reviews, isEmpty);
    });

    test('sebagian gagal: yang berhasil tetap tampil + jumlah gagal',
        () async {
      final repo = CatalogRepository(ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async {
          if (req.url.path.contains('/menus/1/')) {
            return _json({
              'error': {'code': 'NOT_FOUND', 'message': 'Menu tidak ditemukan.'}
            }, 404);
          }
          return _json({
            'data': [_review('An', '2026-11-12T05:00:00Z')]
          });
        }),
      ));
      final r = await loadStoreReviews(repo, [_menu(1, 3), _menu(2, 3)]);
      expect(r.failed, 1);
      expect(r.reviews, hasLength(1));
    });

    test('semua gagal: galat diteruskan', () async {
      final repo = CatalogRepository(ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async => _json({
              'error': {'code': 'INTERNAL_ERROR', 'message': 'Server sibuk.'}
            }, 500)),
      ));
      expect(
        () => loadStoreReviews(repo, [_menu(1, 3), _menu(2, 3)]),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Server sibuk.')),
      );
    });
  });
}
