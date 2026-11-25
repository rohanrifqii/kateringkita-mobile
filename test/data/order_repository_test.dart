import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

OrderRepository _repo(MockClientHandler h) => OrderRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

Map<String, dynamic> orderJson({String code = 'KK-1', int total = 25000}) => {
      'code': code,
      'status': 'holding',
      'payment_method': 'online',
      'payment_status': 'unpaid',
      'pickup_point': {'id': 1, 'name': 'Gerbang Barat'},
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Nasi Box',
          'qty': 1,
          'unit_price': 25000,
          'options': [],
          'line_total': 25000
        }
      ],
      'subtotal': total,
      'discount': 0,
      'service_fee': 0,
      'total': total,
      'created_at': '2026-11-12T03:00:00Z',
      'updated_at': '2026-11-12T03:00:00Z',
      'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62812'},
    };

Map<String, dynamic> quoteJson({List<Map<String, dynamic>> warnings = const []}) => {
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Nasi Box',
          'qty': 2,
          'unit_price': 20000,
          'options': [],
          'line_total': 40000,
          'available': true
        }
      ],
      'subtotal': 40000,
      'discount': 0,
      'service_fee': 1000,
      'total': 41000,
      'warnings': warnings,
    };

void main() {
  test('create sends exact Idempotency-Key and body, parses order', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(201, {'data': orderJson()});
    });
    final o = await r.create({
      'items': [],
      'payment_method': 'va',
    }, idempotencyKey: 'abc-123');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/orders');
    expect(seen.headers['Idempotency-Key'], 'abc-123');
    expect(jsonDecode(seen.body)['payment_method'], 'va');
    expect(o.code, 'KK-1');
    expect(o.total, 25000);
  });

  test('quote returns warnings', () async {
    final r = _repo((req) async {
      expect(req.url.path, '/api/v1/orders/quote');
      expect(req.method, 'POST');
      return _json(200, {
        'data': quoteJson(warnings: [
          {
            'code': 'LOW_STOCK',
            'menu_id': 7,
            'available': 1,
            'message': 'Sisa 1 porsi.'
          }
        ])
      });
    });
    final q = await r.quote({'items': []});
    expect(q.total, 41000);
    expect(q.warnings.single.message, 'Sisa 1 porsi.');
  });

  test('409 MERCHANT_CLOSED surfaces as ApiException code', () async {
    final r = _repo((req) async => _json(409, {
          'error': {'code': 'MERCHANT_CLOSED', 'message': 'Toko sedang tutup.'}
        }));
    expect(
        r.create({}, idempotencyKey: 'k'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'MERCHANT_CLOSED')
            .having((e) => e.message, 'message', 'Toko sedang tutup.')));
  });

  test('list builds query and returns total', () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {
        'data': [orderJson()],
        'meta': {'page': 1, 'limit': 20, 'total': 5}
      });
    });
    final res = await r.list(tab: 'active');
    expect(url.toString(),
        'https://x.test/api/v1/me/orders?tab=active&page=1&limit=20');
    expect(res.items.single.code, 'KK-1');
    expect(res.total, 5);
  });

  test('list passes q when given', () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {'data': [], 'meta': {'total': 0}});
    });
    await r.list(tab: 'completed', q: 'nasi', page: 2, limit: 10);
    expect(url.queryParameters,
        {'tab': 'completed', 'q': 'nasi', 'page': '2', 'limit': '10'});
  });

  test('get, createVa, startOnline, complete, cancel hit the right paths',
      () async {
    final seen = <String>[];
    final bodies = <String>[];
    final r = _repo((req) async {
      seen.add('${req.method} ${req.url.path}');
      bodies.add(req.body);
      return _json(200, {'data': orderJson()});
    });
    await r.get('KK-1');
    await r.createVa('KK-1', 'bca');
    await r.startOnline('KK-1');
    await r.complete('KK-1');
    await r.cancel('KK-1', reason: 'Salah pesan');
    expect(seen, [
      'GET /api/v1/orders/KK-1',
      'POST /api/v1/orders/KK-1/va',
      'POST /api/v1/orders/KK-1/online',
      'POST /api/v1/orders/KK-1/complete',
      'POST /api/v1/orders/KK-1/cancel',
    ]);
    expect(jsonDecode(bodies[1]), {'bank': 'bca'});
    expect(jsonDecode(bodies[4]), {'reason': 'Salah pesan'});
  });

  test('whatsapp, reorder, review parse', () async {
    final r = _repo((req) async {
      final p = req.url.path;
      if (p.endsWith('/whatsapp')) {
        return _json(200, {
          'data': {'wa_number': '62812', 'message': 'Halo', 'url': 'https://wa.me/62812'}
        });
      }
      if (p.endsWith('/reorder')) {
        return _json(200, {
          'data': {
            'request': {'items': [], 'pickup_point_id': 1},
            'quote': quoteJson(),
          }
        });
      }
      expect(jsonDecode(req.body), {
        'items': [
          {'menu_id': 7, 'rating': 5, 'comment': 'Enak'},
          {'menu_id': 8, 'rating': 4},
        ]
      });
      return _json(201, {
        'data': {'order_code': 'KK-1', 'reviewed_menu_ids': [7, 8]}
      });
    });
    final wa = await r.whatsapp('KK-1');
    expect(wa.waNumber, '62812');
    expect(wa.url, 'https://wa.me/62812');
    final re = await r.reorder('KK-1');
    expect(re.request['pickup_point_id'], 1);
    expect(re.quote.total, 41000);
    final ids = await r.review('KK-1', [
      (menuId: 7, rating: 5, comment: 'Enak'),
      (menuId: 8, rating: 4, comment: null),
    ]);
    expect(ids, [7, 8]);
  });

  test('timeout surfaces as TIMEOUT', () async {
    final r = OrderRepository(ApiClient(
      client: MockClient((req) => Completer<http.Response>().future),
      baseUrl: 'https://x.test/api/v1',
      timeout: const Duration(milliseconds: 10),
    ));
    expect(r.create({}, idempotencyKey: 'k'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TIMEOUT')));
  });
}
