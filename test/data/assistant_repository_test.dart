import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/assistant_repository.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

AssistantRepository _repo(MockClientHandler h) => AssistantRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

const _merchant = {
  'id': 3,
  'slug': 'dapur-a',
  'business_name': 'Dapur A',
  'is_open': true,
};

Map<String, dynamic> _card(int id, String name, int price) => {
      'id': id,
      'name': name,
      'image_url': null,
      'price': price,
      'unit_label': 'porsi',
      'category': {'id': 1, 'name': 'Nasi', 'slug': 'nasi'},
      'merchant': _merchant,
      'available': 40,
      'badge': 'available',
      'rating_avg': 4.5,
      'rating_count': 3,
      'is_favorite': false,
    };

Map<String, dynamic> _response({String source = 'ai'}) => {
      'data': {
        'source': source,
        'summary': 'Nasi box cukup untuk 30 orang.',
        'groups': [
          {
            'merchant': _merchant,
            'items': [
              {
                'menu': _card(7, 'Nasi Box', 15000),
                'qty': 30,
                'subtotal': 450000,
                'reason': 'Mengenyangkan untuk rapat',
              },
              {
                'menu': _card(8, 'Es Teh', 3000),
                'qty': 30,
                'subtotal': 90000,
                'reason': null,
              },
            ],
            'total': 540000,
          }
        ],
        'total': 540000,
      }
    };

void main() {
  test('POST /assistant/recommendations hanya dengan field yang diisi',
      () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(200, _response());
    });
    await r.recommend(question: '  makan siang rapat 30 orang  ');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/assistant/recommendations');
    expect(jsonDecode(seen.body), {'question': 'makan siang rapat 30 orang'});
  });

  test('budget/portions angka JSON, category slug, pickup_point_id', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(200, _response());
    });
    await r.recommend(
      question: 'snack rapat',
      budget: 500000,
      portions: 30,
      category: 'snack',
      merchant: 'dapur-a',
      pickupPointId: 2,
    );
    expect(jsonDecode(seen.body), {
      'question': 'snack rapat',
      'budget': 500000,
      'portions': 30,
      'category': 'snack',
      'merchant': 'dapur-a',
      'pickup_point_id': 2,
    });
  });

  test('respons: ringkasan, grup per toko, kartu menu, qty, alasan, total',
      () async {
    final r = _repo((req) async => _json(200, _response()));
    final rec = await r.recommend(question: 'nasi box');
    expect(rec.isAi, isTrue);
    expect(rec.summary, 'Nasi box cukup untuk 30 orang.');
    expect(rec.total, 540000);
    expect(rec.groups, hasLength(1));
    final g = rec.groups.single;
    expect(g.merchant.businessName, 'Dapur A');
    expect(g.total, 540000);
    expect(g.items.first.menu.id, 7);
    expect(g.items.first.menu.price, 15000);
    expect(g.items.first.menu.merchant.slug, 'dapur-a');
    expect(g.items.first.qty, 30);
    expect(g.items.first.subtotal, 450000);
    expect(g.items.first.reason, 'Mengenyangkan untuk rapat');
    expect(g.items.last.reason, isNull);
  });

  test('cadangan tanpa AI dan hasil kosong', () async {
    final r = _repo((req) async => _json(200, {
          'data': {
            'source': 'fallback',
            'summary': 'Belum ada menu tersedia yang cocok.',
            'groups': [],
            'total': 0,
          }
        }));
    final rec = await r.recommend(question: 'apa saja');
    expect(rec.isAi, isFalse);
    expect(rec.groups, isEmpty);
    expect(rec.total, 0);
  });

  test('429 diteruskan sebagai ApiException', () async {
    final r = _repo((req) async => _json(429, {
          'error': {
            'code': 'RATE_LIMITED',
            'message': 'Terlalu banyak pertanyaan. Coba lagi beberapa menit lagi.'
          }
        }));
    expect(
      () => r.recommend(question: 'nasi'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
    );
  });
}
