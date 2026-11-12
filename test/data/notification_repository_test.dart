import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

NotificationRepository _repo(MockClientHandler h) => NotificationRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

Map<String, dynamic> _notif(int id,
        {String type = 'order_status', Object? data, String? readAt}) =>
    {
      'id': id,
      'type': type,
      'title': 'Pesanan siap diambil',
      'body': 'Pesanan KK-1 sudah siap.',
      'data': data ?? {'order_code': 'KK-1', 'status': 'ready'},
      'read_at': readAt,
      'created_at': '2026-11-13T03:00:00.000Z',
    };

void main() {
  test('list: GET /me/notifications, parse item + meta.unread_count',
      () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {
        'data': [
          _notif(2),
          _notif(1,
              type: 'promo',
              data: {'promo_code': 'HEMAT', 'merchant_id': 3},
              readAt: '2026-11-13T04:00:00.000Z'),
        ],
        'meta': {'page': 1, 'limit': 20, 'total': 2, 'unread_count': 5},
      });
    });
    final page = await r.list();
    expect(url.toString(),
        'https://x.test/api/v1/me/notifications?page=1&limit=20');
    expect(page.total, 2);
    expect(page.unreadCount, 5);
    final a = page.items.first;
    expect(a.id, 2);
    expect(a.isOrderStatus, isTrue);
    expect(a.orderCode, 'KK-1');
    expect(a.orderStatus, 'ready');
    expect(a.isRead, isFalse);
    expect(a.createdAt, DateTime.utc(2026, 11, 13, 3));
    final b = page.items.last;
    expect(b.type, 'promo');
    expect(b.orderCode, isNull);
    expect(b.isRead, isTrue);
  });

  test('list unreadOnly menambah unread=true; page/limit diteruskan',
      () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {
        'data': [],
        'meta': {'page': 2, 'limit': 1, 'total': 0, 'unread_count': 0},
      });
    });
    await r.list(page: 2, limit: 1, unreadOnly: true);
    expect(url.queryParameters,
        {'page': '2', 'limit': '1', 'unread': 'true'});
  });

  test('data sebagai string JSON atau null tetap terbaca', () async {
    final r = _repo((req) async => _json(200, {
          'data': [
            _notif(1, data: '{"order_code":"KK-9","status":"cancelled"}'),
            {..._notif(2, type: 'info'), 'data': null},
          ],
          'meta': {'total': 2, 'unread_count': 2},
        }));
    final page = await r.list();
    expect(page.items.first.orderCode, 'KK-9');
    expect(page.items.first.orderStatus, 'cancelled');
    expect(page.items.last.data, isEmpty);
  });

  test('unreadCount: hanya meta.unread_count dari permintaan ringan',
      () async {
    late Uri url;
    final r = _repo((req) async {
      url = req.url;
      return _json(200, {
        'data': [_notif(1)],
        'meta': {'page': 1, 'limit': 1, 'total': 4, 'unread_count': 4},
      });
    });
    expect(await r.unreadCount(), 4);
    expect(url.queryParameters['limit'], '1');
    expect(url.queryParameters['unread'], 'true');
  });

  test('markRead: POST {ids}, kembalikan unread_count dari data', () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(200, {
        'data': {'unread_count': 3}
      });
    });
    expect(await r.markRead([5, 6]), 3);
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/me/notifications/read');
    expect(jsonDecode(seen.body), {
      'ids': [5, 6]
    });
  });

  test('markAllRead: POST {all: true} (backend menolak body kosong)',
      () async {
    late http.Request seen;
    final r = _repo((req) async {
      seen = req;
      return _json(200, {
        'data': {'unread_count': 0}
      });
    });
    expect(await r.markAllRead(), 0);
    expect(jsonDecode(seen.body), {'all': true});
  });

  test('galat server diteruskan sebagai ApiException', () async {
    final r = _repo((req) async => _json(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid.',
            'fields': {
              'ids': ['Pilih notifikasi yang ditandai.']
            }
          }
        }));
    expect(
      () => r.markRead([]),
      throwsA(isA<ApiException>()
          .having((e) => e.field('ids'), 'ids', 'Pilih notifikasi yang ditandai.')),
    );
  });
}
