import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/ticket_repository.dart';
import 'package:kateringkita_pbl/models/support_ticket.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _err(int status, String code, String message,
        [Map<String, Object>? fields]) =>
    _json(status, {
      'error': {'code': code, 'message': message, 'fields': ?fields},
    });

TicketRepository _repo(MockClientHandler h) => TicketRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

Map<String, dynamic> _summary(String code,
        {String status = 'answered',
        bool unread = true,
        String? orderCode = 'KK-20261113-DC4T'}) =>
    {
      'code': code,
      'category': 'pembayaran',
      'subject': 'VA sudah dibayar tapi status belum lunas',
      'status': status,
      'order_code': orderCode,
      'created_at': '2026-11-13T02:00:00.000Z',
      'last_message_at': '2026-11-13T03:30:00.000Z',
      'last_message_preview': 'Sudah kami cek, pembayaranmu masuk.',
      'last_sender_role': 'admin',
      'unread': unread,
    };

Map<String, dynamic> _detail(String code,
        {String status = 'open', String? closedAt, String? closedBy}) =>
    {
      'code': code,
      'category': 'pembayaran',
      'subject': 'VA sudah dibayar tapi status belum lunas',
      'status': status,
      'order_code': 'KK-20261113-DC4T',
      'created_at': '2026-11-13T02:00:00.000Z',
      'last_message_at': '2026-11-13T03:30:00.000Z',
      'last_sender_role': 'admin',
      'closed_at': closedAt,
      'closed_by': closedBy,
      'messages': [
        {
          'id': 1,
          'sender_role': 'customer',
          'sender_name': null,
          'body': 'Sudah bayar VA BCA tapi masih menunggu.',
          'created_at': '2026-11-13T02:00:00.000Z',
        },
        {
          'id': 2,
          'sender_role': 'admin',
          'sender_name': 'Tim KateringKita',
          'body': 'Sudah kami cek, pembayaranmu masuk.',
          'created_at': '2026-11-13T03:30:00.000Z',
        },
      ],
    };

void main() {
  group('list', () {
    test('GET /me/tickets?page&limit, parse item + meta.unread_count',
        () async {
      late http.Request seen;
      final r = _repo((req) async {
        seen = req;
        return _json(200, {
          'data': [
            _summary('TK-20261113-7QPX'),
            _summary('TK-20261112-AB2C',
                status: 'closed', unread: false, orderCode: null),
          ],
          'meta': {'page': 1, 'limit': 20, 'total': 5, 'unread_count': 3},
        });
      });
      final page = await r.list();
      expect(seen.method, 'GET');
      expect(seen.url.toString(),
          'https://x.test/api/v1/me/tickets?page=1&limit=20');
      expect(page.total, 5);
      expect(page.page, 1);
      expect(page.unreadCount, 3);
      expect(page.items, hasLength(2));

      final a = page.items.first;
      expect(a.code, 'TK-20261113-7QPX');
      expect(a.category, 'pembayaran');
      expect(a.categoryLabel, 'Pembayaran');
      expect(a.subject, 'VA sudah dibayar tapi status belum lunas');
      expect(a.status, 'answered');
      expect(a.statusLabel, 'Dibalas');
      expect(a.isClosed, isFalse);
      expect(a.orderCode, 'KK-20261113-DC4T');
      expect(a.createdAt, DateTime.utc(2026, 11, 13, 2));
      expect(a.lastMessageAt, DateTime.utc(2026, 11, 13, 3, 30));
      expect(a.lastMessagePreview, 'Sudah kami cek, pembayaranmu masuk.');
      expect(a.lastSenderRole, 'admin');
      expect(a.unread, isTrue);

      final b = page.items.last;
      expect(b.isClosed, isTrue);
      expect(b.statusLabel, 'Ditutup');
      expect(b.orderCode, isNull);
      expect(b.unread, isFalse);
    });

    test('halaman & limit diteruskan; tanpa meta: total & unread dari isi',
        () async {
      late Uri url;
      final r = _repo((req) async {
        url = req.url;
        return _json(200, {
          'data': [
            _summary('TK-1'),
            _summary('TK-2', unread: false),
          ],
        });
      });
      final page = await r.list(page: 3, limit: 50);
      expect(url.queryParameters, {'page': '3', 'limit': '50'});
      expect(page.page, 3);
      expect(page.total, 2);
      expect(page.unreadCount, 1);
    });

    test('unreadCount: GET limit=1, angka dari meta', () async {
      late Uri url;
      final r = _repo((req) async {
        url = req.url;
        return _json(200, {
          'data': [_summary('TK-1', unread: false)],
          'meta': {'page': 1, 'limit': 1, 'total': 9, 'unread_count': 4},
        });
      });
      expect(await r.unreadCount(), 4);
      expect(url.path, '/api/v1/me/tickets');
      expect(url.queryParameters['limit'], '1');
    });
  });

  group('create', () {
    test('POST /me/tickets dengan isi dirapikan, hasil TicketDetail',
        () async {
      late http.Request seen;
      final r = _repo((req) async {
        seen = req;
        return _json(201, {'data': _detail('TK-20261113-7QPX')});
      });
      final t = await r.create(
        category: 'pembayaran',
        subject: '  VA sudah dibayar tapi status belum lunas ',
        message: ' Sudah bayar VA BCA tapi masih menunggu.  ',
        orderCode: 'KK-20261113-DC4T',
      );
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/me/tickets');
      expect(jsonDecode(seen.body), {
        'category': 'pembayaran',
        'subject': 'VA sudah dibayar tapi status belum lunas',
        'message': 'Sudah bayar VA BCA tapi masih menunggu.',
        'order_code': 'KK-20261113-DC4T',
      });
      expect(t.code, 'TK-20261113-7QPX');
      expect(t.status, 'open');
      expect(t.statusLabel, 'Menunggu admin');
      expect(t.messages, hasLength(2));
    });

    test('order_code kosong tidak dikirim', () async {
      final bodies = <Object?>[];
      final r = _repo((req) async {
        bodies.add(jsonDecode(req.body));
        return _json(201, {'data': _detail('TK-1')});
      });
      await r.create(category: 'akun', subject: 'Abc', message: 'Halo admin');
      await r.create(
          category: 'akun',
          subject: 'Abc',
          message: 'Halo admin',
          orderCode: '  ');
      for (final b in bodies) {
        expect((b as Map).containsKey('order_code'), isFalse);
      }
    });

    test('400 VALIDATION_ERROR: pesan & fields server diteruskan', () async {
      final r = _repo((req) async => _err(400, 'VALIDATION_ERROR',
              'Data tidak valid.', {
            'subject': ['Judul 3–120 karakter.'],
            'order_code': ['Pesanan tidak ditemukan.'],
          }));
      await expectLater(
        r.create(
            category: 'pesanan',
            subject: 'Ab',
            message: 'Halo admin',
            orderCode: 'KK-X'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 400)
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')
            .having((e) => e.field('subject'), 'subject',
                'Judul 3–120 karakter.')
            .having((e) => e.field('order_code'), 'order_code',
                'Pesanan tidak ditemukan.')),
      );
    });

    test('409 TOO_MANY_OPEN_TICKETS: pesan server apa adanya', () async {
      const msg = 'Masih ada 3 tiket yang belum selesai. '
          'Tunggu balasan atau tutup salah satunya.';
      final r = _repo((req) async => _err(409, 'TOO_MANY_OPEN_TICKETS', msg));
      await expectLater(
        r.create(category: 'akun', subject: 'Abc', message: 'Halo admin'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'TOO_MANY_OPEN_TICKETS')
            .having((e) => e.message, 'message', msg)),
      );
    });
  });

  group('detail', () {
    test('GET /me/tickets/:code (kode di-encode), parse pesan', () async {
      late http.Request seen;
      final r = _repo((req) async {
        seen = req;
        return _json(200, {
          'data': _detail('TK-20261113-7QPX',
              status: 'closed',
              closedAt: '2026-11-13T05:00:00.000Z',
              closedBy: 'admin'),
        });
      });
      final t = await r.get('TK-20261113-7QPX');
      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/v1/me/tickets/TK-20261113-7QPX');
      expect(t.code, 'TK-20261113-7QPX');
      expect(t.category, 'pembayaran');
      expect(t.categoryLabel, 'Pembayaran');
      expect(t.subject, 'VA sudah dibayar tapi status belum lunas');
      expect(t.orderCode, 'KK-20261113-DC4T');
      expect(t.isClosed, isTrue);
      expect(t.closedAt, DateTime.utc(2026, 11, 13, 5));
      expect(t.closedBy, 'admin');
      expect(t.lastMessageAt, DateTime.utc(2026, 11, 13, 3, 30));

      final customer = t.messages.first;
      expect(customer.id, 1);
      expect(customer.fromAdmin, isFalse);
      expect(customer.senderName, isNull);
      expect(customer.body, 'Sudah bayar VA BCA tapi masih menunggu.');
      expect(customer.createdAt, DateTime.utc(2026, 11, 13, 2));

      final admin = t.messages.last;
      expect(admin.fromAdmin, isTrue);
      expect(admin.senderName, 'Tim KateringKita');
      expect(admin.displayName, 'Tim KateringKita');
    });

    test('kode dengan karakter khusus di-encode', () async {
      late Uri url;
      final r = _repo((req) async {
        url = req.url;
        return _json(200, {'data': _detail('TK 1/2')});
      });
      await r.get('TK 1/2');
      expect(url.toString(), 'https://x.test/api/v1/me/tickets/TK%201%2F2');
    });

    test('404: "Tiket tidak ditemukan."', () async {
      final r = _repo(
          (req) async => _err(404, 'NOT_FOUND', 'Tiket tidak ditemukan.'));
      await expectLater(
        r.get('TK-X'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.message, 'message', 'Tiket tidak ditemukan.')),
      );
    });
  });

  group('reply & close', () {
    test('reply: POST /me/tickets/:code/messages {body} dirapikan', () async {
      late http.Request seen;
      final r = _repo((req) async {
        seen = req;
        return _json(201, {'data': _detail('TK-1')});
      });
      final t = await r.reply('TK-1', '  Terima kasih!  ');
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/me/tickets/TK-1/messages');
      expect(jsonDecode(seen.body), {'body': 'Terima kasih!'});
      expect(t.code, 'TK-1');
    });

    test('reply ke tiket tertutup: 409 TICKET_CLOSED', () async {
      const msg = 'Tiket sudah ditutup. Buat tiket baru bila masih perlu '
          'bantuan.';
      final r = _repo((req) async => _err(409, 'TICKET_CLOSED', msg));
      await expectLater(
        r.reply('TK-1', 'Halo'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'TICKET_CLOSED')
            .having((e) => e.message, 'message', msg)),
      );
    });

    test('reply: fields.body diteruskan', () async {
      final r = _repo((req) async => _err(400, 'VALIDATION_ERROR',
          'Data tidak valid.', {'body': 'Pesan 1–2000 karakter.'}));
      await expectLater(
        r.reply('TK-1', 'x'),
        throwsA(isA<ApiException>().having(
            (e) => e.field('body'), 'body', 'Pesan 1–2000 karakter.')),
      );
    });

    test('close: POST /me/tickets/:code/close, status closed', () async {
      late http.Request seen;
      final r = _repo((req) async {
        seen = req;
        return _json(200, {
          'data': _detail('TK-1',
              status: 'closed',
              closedAt: '2026-11-13T06:00:00.000Z',
              closedBy: 'customer'),
        });
      });
      final t = await r.close('TK-1');
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/me/tickets/TK-1/close');
      expect(t.isClosed, isTrue);
      expect(t.closedBy, 'customer');
    });
  });

  group('model', () {
    test('label kategori & status sesuai kontrak', () {
      expect(ticketCategories.keys, [
        'akun',
        'pembayaran',
        'pesanan',
        'penjual',
        'aplikasi',
        'lainnya',
      ]);
      expect(ticketCategories.values, [
        'Akun',
        'Pembayaran',
        'Pesanan',
        'Penjual',
        'Aplikasi',
        'Lainnya',
      ]);
      expect(ticketStatusLabel('open'), 'Menunggu admin');
      expect(ticketStatusLabel('answered'), 'Dibalas');
      expect(ticketStatusLabel('closed'), 'Ditutup');
      expect(ticketCategoryLabel('aneh'), 'Lainnya');
    });

    test('pesan admin tanpa sender_name tampil "Tim KateringKita"', () {
      final m = TicketMessage.fromJson({
        'id': 5,
        'sender_role': 'admin',
        'body': 'Halo',
        'created_at': '2026-11-13T02:00:00.000Z',
      });
      expect(m.displayName, 'Tim KateringKita');
    });

    test('validasi klien sama dengan server (setelah trim)', () {
      expect(TicketRules.category(null), 'Pilih kategori.');
      expect(TicketRules.category('lain'), 'Pilih kategori.');
      expect(TicketRules.category('akun'), isNull);

      expect(TicketRules.subject('  ab  '), 'Judul 3–120 karakter.');
      expect(TicketRules.subject(' abc '), isNull);
      expect(TicketRules.subject('a' * 120), isNull);
      expect(TicketRules.subject('a' * 121), 'Judul 3–120 karakter.');

      expect(TicketRules.message('abcd'), 'Pesan 5–2000 karakter.');
      expect(TicketRules.message('   abcd   '), 'Pesan 5–2000 karakter.');
      expect(TicketRules.message('abcde'), isNull);
      expect(TicketRules.message('a' * 2000), isNull);
      expect(TicketRules.message('a' * 2001), 'Pesan 5–2000 karakter.');

      expect(TicketRules.reply('   '), 'Pesan 1–2000 karakter.');
      expect(TicketRules.reply('a'), isNull);
      expect(TicketRules.reply('a' * 2000), isNull);
      expect(TicketRules.reply('a' * 2001), 'Pesan 1–2000 karakter.');
    });
  });
}
