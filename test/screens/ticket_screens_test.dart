import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/core/pickup_time.dart';
import 'package:kateringkita_pbl/core/relative_time.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/data/ticket_repository.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/ticket_unread_provider.dart';
import 'package:kateringkita_pbl/screens/support/ticket_create_screen.dart';
import 'package:kateringkita_pbl/screens/support/ticket_detail_screen.dart';
import 'package:kateringkita_pbl/screens/support/ticket_list_screen.dart';
import 'package:provider/provider.dart';

import '../support/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _err(int status, String code, String message,
        [Map<String, Object>? fields]) =>
    _json({
      'error': {'code': code, 'message': message, 'fields': ?fields},
    }, status);

String _ago(Duration d) =>
    DateTime.now().toUtc().subtract(d).toIso8601String();

const _t0 = '2026-11-13T02:00:00.000Z';
const _t1 = '2026-11-13T03:30:00.000Z';

Map<String, dynamic> _summary(String code,
        {String subject = 'VA sudah dibayar tapi status belum lunas',
        String category = 'pembayaran',
        String status = 'answered',
        String preview = 'Sudah kami cek, pembayaranmu masuk.',
        String lastSender = 'admin',
        bool unread = false,
        Duration ago = const Duration(minutes: 5)}) =>
    {
      'code': code,
      'category': category,
      'subject': subject,
      'status': status,
      'order_code': null,
      'created_at': _ago(ago + const Duration(hours: 1)),
      'last_message_at': _ago(ago),
      'last_message_preview': preview,
      'last_sender_role': lastSender,
      'unread': unread,
    };

Map<String, dynamic> _detail(String code,
        {String status = 'answered',
        String? orderCode = 'KK-20261113-DC4T',
        String? closedBy}) =>
    {
      'code': code,
      'category': 'pembayaran',
      'subject': 'VA sudah dibayar tapi status belum lunas',
      'status': status,
      'order_code': orderCode,
      'created_at': _t0,
      'last_message_at': _t1,
      'last_sender_role': 'admin',
      'closed_at': status == 'closed' ? _t1 : null,
      'closed_by': closedBy,
      'messages': [
        {
          'id': 1,
          'sender_role': 'customer',
          'sender_name': null,
          'body': 'Sudah bayar VA BCA tapi masih menunggu.',
          'created_at': _t0,
        },
        {
          'id': 2,
          'sender_role': 'admin',
          'sender_name': 'Tim KateringKita',
          'body': 'Sudah kami cek, pembayaranmu masuk.',
          'created_at': _t1,
        },
      ],
    };

Map<String, dynamic> _order(String code, String store, String createdAt) => {
      'code': code,
      'status': 'completed',
      'payment_method': 'online',
      'payment_status': 'paid',
      'pickup_point': {'id': 1, 'name': 'Gerbang Barat'},
      'items': [],
      'subtotal': 25000,
      'discount': 0,
      'service_fee': 0,
      'total': 25000,
      'created_at': createdAt,
      'updated_at': createdAt,
      'merchant': {'id': 1, 'business_name': store, 'wa_number': '62812'},
    };

/// Server palsu `/me/tickets` + `/me/orders` dengan status di memori.
/// [override] boleh mengembalikan jawaban khusus (null = perilaku bawaan).
class _Server {
  final requests = <http.Request>[];
  final tickets = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> summaries = [];
  int unreadCount = 0;
  Map<String, List<Map<String, dynamic>>> orders = {};
  http.Response? Function(http.Request r)? override;
  int _nextId = 100;

  Iterable<http.Request> where(String method, String path) => requests.where(
      (r) => r.method == method && r.url.path == '/api/v1$path');

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final custom = override?.call(r);
    if (custom != null) return custom;
    final p = r.url.path.replaceFirst('/api/v1', '');
    final q = r.url.queryParameters;

    if (p == '/me/orders') {
      return _json({
        'data': orders[q['tab']] ?? const [],
        'meta': {'total': (orders[q['tab']] ?? const []).length},
      });
    }
    if (p == '/me/tickets' && r.method == 'GET') {
      final page = int.parse(q['page'] ?? '1');
      final limit = int.parse(q['limit'] ?? '20');
      final start = (page - 1) * limit;
      return _json({
        'data': summaries.skip(start).take(limit).toList(),
        'meta': {
          'page': page,
          'limit': limit,
          'total': summaries.length,
          'unread_count': unreadCount,
        },
      });
    }
    if (p == '/me/tickets' && r.method == 'POST') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      const code = 'TK-20261113-NEW1';
      final t = {
        ..._detail(code, status: 'open', orderCode: b['order_code'] as String?),
        'category': b['category'],
        'subject': b['subject'],
        'last_sender_role': 'customer',
        'messages': [
          {
            'id': _nextId++,
            'sender_role': 'customer',
            'sender_name': null,
            'body': b['message'],
            'created_at': _t0,
          }
        ],
      };
      tickets[code] = t;
      return _json({'data': t}, 201);
    }
    final m = RegExp(r'^/me/tickets/([^/]+)(/messages|/close)?$').firstMatch(p);
    if (m != null) {
      final t = tickets[Uri.decodeComponent(m.group(1)!)];
      if (t == null) return _err(404, 'NOT_FOUND', 'Tiket tidak ditemukan.');
      switch (m.group(2)) {
        case null:
          return _json({'data': t});
        case '/messages':
          if (t['status'] == 'closed') {
            return _err(409, 'TICKET_CLOSED',
                'Tiket sudah ditutup. Buat tiket baru bila masih perlu bantuan.');
          }
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          t['status'] = 'open';
          t['last_sender_role'] = 'customer';
          t['messages'] = [
            ...t['messages'] as List,
            {
              'id': _nextId++,
              'sender_role': 'customer',
              'sender_name': null,
              'body': b['body'],
              'created_at': _t1,
            },
          ];
          return _json({'data': t}, 201);
        case '/close':
          t['status'] = 'closed';
          t['closed_by'] = 'customer';
          t['closed_at'] = _t1;
          return _json({'data': t});
      }
    }
    return _err(404, 'NOT_FOUND', 'x');
  }
}

class _Harness {
  _Harness({FakeAuth? auth}) : auth = auth ?? FakeAuth(loggedIn: true) {
    final api = ApiClient(
        baseUrl: 'https://x.test/api/v1', client: MockClient(server.handle));
    tickets = TicketRepository(api);
    unread = TicketUnreadProvider(tickets);
    orders = OrderRepository(api);
  }

  final server = _Server();
  final FakeAuth auth;
  final navKey = GlobalKey<NavigatorState>();
  late final TicketRepository tickets;
  late final TicketUnreadProvider unread;
  late final OrderRepository orders;

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<TicketRepository>.value(value: tickets),
          ChangeNotifierProvider<TicketUnreadProvider>.value(value: unread),
          Provider<OrderRepository>.value(value: orders),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('beranda')),
          routes: {
            AppRoutes.tickets: (_) => const TicketListScreen(),
            AppRoutes.ticketCreate: (_) => const TicketCreateScreen(),
            AppRoutes.ticketDetail: (_) => const TicketDetailScreen(),
            AppRoutes.orders: (_) =>
                const Scaffold(body: Text('layar-pesanan')),
            AppRoutes.login: (_) => const Scaffold(body: Text('layar-login')),
          },
        ),
      );

  Future<void> open(WidgetTester tester, String route,
      {Object? arguments}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    navKey.currentState!.pushNamed(route, arguments: arguments);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('daftar tiket', () {
    testWidgets('kosong: arahan WA penjual, tombol Pesanan & Buat tiket',
        (tester) async {
      final h = _Harness();
      await h.open(tester, AppRoutes.tickets);

      expect(h.server.where('GET', '/me/tickets'), hasLength(1));
      expect(
          find.text('Pertanyaan soal pesanan? Hubungi penjual lewat tombol '
              'WhatsApp di Pesanan.'),
          findsOneWidget);
      expect(find.text('Belum ada tiket'), findsOneWidget);
      expect(find.text('Buat tiket'), findsOneWidget);

      await tester.tap(find.text('Buka Pesanan'));
      await tester.pumpAndSettle();
      expect(find.text('layar-pesanan'), findsOneWidget);
    });

    testWidgets('item: judul, kode, kategori, status, pratinjau, titik',
        (tester) async {
      final h = _Harness();
      h.server
        ..unreadCount = 4
        ..summaries = [
          _summary('TK-1', unread: true),
          _summary('TK-2',
              subject: 'Tidak bisa ganti email',
              category: 'akun',
              status: 'open',
              preview: 'Email saya salah ketik',
              lastSender: 'customer',
              ago: const Duration(hours: 3)),
          _summary('TK-3',
              subject: 'Aplikasi keluar sendiri',
              category: 'aplikasi',
              status: 'closed',
              ago: const Duration(days: 3)),
        ];
      await h.open(tester, AppRoutes.tickets);

      expect(find.text('VA sudah dibayar tapi status belum lunas'),
          findsOneWidget);
      expect(find.text('TK-1 · Pembayaran'), findsOneWidget);
      expect(find.text('TK-2 · Akun'), findsOneWidget);
      expect(find.text('TK-3 · Aplikasi'), findsOneWidget);
      expect(find.text('Dibalas'), findsOneWidget);
      expect(find.text('Menunggu admin'), findsOneWidget);
      expect(find.text('Ditutup'), findsOneWidget);
      expect(find.text('Tim KateringKita: Sudah kami cek, pembayaranmu masuk.'),
          findsNWidgets(2));
      expect(find.text('Kamu: Email saya salah ketik'), findsOneWidget);
      expect(find.text('5 menit lalu'), findsOneWidget);
      expect(find.text('3 hari lalu'), findsOneWidget);
      expect(
          find.text(relativeTimeWib(DateTime.parse(
              h.server.summaries[1]['last_message_at'] as String))),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-unread-TK-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-unread-TK-2')), findsNothing);
      expect(find.byKey(const ValueKey('ticket-unread-TK-3')), findsNothing);
      expect(find.text('Belum ada tiket'), findsNothing);
      // meta.unread_count dipakai titik di Profil.
      expect(h.unread.unreadCount, 4);
    });

    testWidgets('muat lebih banyak memakai halaman berikutnya',
        (tester) async {
      final h = _Harness();
      h.server.summaries = [
        for (var i = 1; i <= 25; i++)
          _summary('TK-$i', subject: 'Tiket nomor $i'),
      ];
      await h.open(tester, AppRoutes.tickets);
      expect(find.text('Tiket nomor 25'), findsNothing);
      await tester.scrollUntilVisible(find.text('Muat lebih banyak'), 300);
      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();
      expect(h.server.where('GET', '/me/tickets').last.url.queryParameters,
          {'page': '2', 'limit': '20'});
      await tester.scrollUntilVisible(find.text('Tiket nomor 25'), 300);
      expect(find.text('Tiket nomor 25'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsNothing);
    });

    testWidgets('ketuk item membuka detail; kembali memuat ulang daftar',
        (tester) async {
      final h = _Harness();
      h.server
        ..summaries = [_summary('TK-1', unread: true)]
        ..tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.tickets);
      await tester.tap(find.text('VA sudah dibayar tapi status belum lunas'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      expect(h.server.where('GET', '/me/tickets/TK-1'), hasLength(1));

      // Sudah dibaca di server.
      h.server.summaries = [_summary('TK-1')];
      Navigator.of(tester.element(find.byType(TicketDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(h.server.where('GET', '/me/tickets'), hasLength(greaterThan(1)));
      expect(find.byKey(const ValueKey('ticket-unread-TK-1')), findsNothing);
    });

    testWidgets('tarik untuk memuat ulang', (tester) async {
      final h = _Harness();
      h.server.summaries = [_summary('TK-1')];
      await h.open(tester, AppRoutes.tickets);
      h.server.summaries = [
        _summary('TK-9', subject: 'Tiket paling baru'),
        _summary('TK-1'),
      ];
      await tester.fling(
          find.text('TK-1 · Pembayaran'), const Offset(0, 900), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Tiket paling baru'), findsOneWidget);
    });

    testWidgets('galat + Coba Lagi', (tester) async {
      final h = _Harness();
      var fail = true;
      h.server.override = (r) =>
          fail ? _err(503, 'UNAVAILABLE', 'Server sibuk.') : null;
      await h.open(tester, AppRoutes.tickets);
      expect(find.text('Server sibuk.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada tiket'), findsOneWidget);
    });

    testWidgets('tamu: ajakan masuk tanpa permintaan', (tester) async {
      final h = _Harness(auth: FakeAuth());
      await h.open(tester, AppRoutes.tickets);
      expect(find.text('Masuk untuk melihat tiket bantuan'), findsOneWidget);
      expect(find.text('Buat tiket'), findsNothing);
      expect(h.server.requests, isEmpty);
    });
  });

  group('buat tiket', () {
    Finder field(String key) => find.byKey(ValueKey(key));

    testWidgets('validasi klien = server, tanpa permintaan', (tester) async {
      final h = _Harness();
      await h.open(tester, AppRoutes.ticketCreate);
      expect(find.text('0/120'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);

      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih kategori.'), findsOneWidget);
      expect(find.text('Judul 3–120 karakter.'), findsOneWidget);
      expect(find.text('Pesan 5–2000 karakter.'), findsOneWidget);

      await tester.tap(find.text('Akun'));
      await tester.enterText(field('ticket-subject'), '  ab  ');
      await tester.enterText(field('ticket-message'), ' abcd ');
      await tester.pump();
      expect(find.text('2/120'), findsOneWidget);
      expect(find.text('4/2000'), findsOneWidget);
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih kategori.'), findsNothing);
      expect(find.text('Judul 3–120 karakter.'), findsOneWidget);
      expect(find.text('Pesan 5–2000 karakter.'), findsOneWidget);

      await tester.enterText(field('ticket-subject'), 'a' * 121);
      await tester.pump();
      expect(find.text('121/120'), findsOneWidget);
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      expect(find.text('Judul 3–120 karakter.'), findsOneWidget);
      expect(h.server.requests, isEmpty);
    });

    testWidgets('kategori Pesanan: arahan WA penjual, tetap bisa dikirim',
        (tester) async {
      final h = _Harness();
      await h.open(tester, AppRoutes.ticketCreate);
      final hint = find.byKey(const ValueKey('ticket-order-hint'));
      expect(hint, findsNothing);
      await tester.tap(find.text('Pesanan'));
      await tester.pump();
      expect(hint, findsOneWidget);
      expect(
          find.textContaining('lebih cepat dijawab penjual lewat tombol '
              'WhatsApp di Pesanan'),
          findsOneWidget);
      await tester.tap(find.text('Penjual'));
      await tester.pump();
      expect(hint, findsNothing);

      await tester.tap(find.text('Pesanan'));
      await tester.enterText(field('ticket-subject'), 'Minta pengembalian');
      await tester.enterText(
          field('ticket-message'), 'Penjual tidak membalas sejak kemarin.');
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      final post = h.server.where('POST', '/me/tickets').single;
      expect(jsonDecode(post.body)['category'], 'pesanan');
    });

    testWidgets('galat per kolom dari server tampil di kolomnya',
        (tester) async {
      final h = _Harness();
      h.server.override = (r) => r.method == 'POST'
          ? _err(400, 'VALIDATION_ERROR', 'Data tidak valid.', {
              'subject': ['Judul sudah dipakai.'],
              'order_code': ['Pesanan tidak ditemukan.'],
            })
          : null;
      await h.open(tester, AppRoutes.ticketCreate);
      await tester.tap(find.text('Akun'));
      await tester.enterText(field('ticket-subject'), 'Tidak bisa masuk');
      await tester.enterText(
          field('ticket-message'), 'Selalu gagal walau sandi benar.');
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      expect(find.text('Judul sudah dipakai.'), findsOneWidget);
      expect(find.text('Pesanan tidak ditemukan.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-server-error')), findsNothing);
      expect(find.byType(TicketCreateScreen), findsOneWidget);
    });

    testWidgets('409 TOO_MANY_OPEN_TICKETS: pesan server ditampilkan',
        (tester) async {
      const msg = 'Masih ada 3 tiket yang belum selesai. Tunggu balasan atau '
          'tutup salah satunya.';
      final h = _Harness();
      h.server.override = (r) => r.method == 'POST'
          ? _err(409, 'TOO_MANY_OPEN_TICKETS', msg)
          : null;
      await h.open(tester, AppRoutes.ticketCreate);
      await tester.tap(find.text('Aplikasi'));
      await tester.enterText(field('ticket-subject'), 'Aplikasi lambat');
      await tester.enterText(field('ticket-message'), 'Lambat sekali dibuka.');
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ticket-server-error')), findsOneWidget);
      expect(find.text(msg), findsOneWidget);
      expect(find.byType(TicketCreateScreen), findsOneWidget);
    });

    testWidgets('berhasil dengan pesanan terkait: buka detail tiket baru',
        (tester) async {
      final h = _Harness();
      h.server.orders = {
        'active': [_order('KK-2', 'Dapur B', '2026-11-12T03:00:00.000Z')],
        'completed': [_order('KK-1', 'Dapur A', '2026-11-10T03:00:00.000Z')],
        'cancelled': [],
      };
      await h.open(tester, AppRoutes.ticketCreate);

      await tester.tap(find.byKey(const ValueKey('ticket-order-field')));
      await tester.pumpAndSettle();
      final tabs = h.server
          .where('GET', '/me/orders')
          .map((r) => r.url.queryParameters['tab'])
          .toSet();
      expect(tabs, {'active', 'completed', 'cancelled'});
      // Terbaru dulu: kode, toko, tanggal.
      expect(
          tester.getTopLeft(find.text('KK-2')).dy <
              tester.getTopLeft(find.text('KK-1')).dy,
          isTrue);
      final date = formatWibDate(DateTime.parse('2026-11-10T03:00:00.000Z'));
      expect(find.text('Dapur A · $date'), findsOneWidget);
      await tester.tap(find.text('KK-1'));
      await tester.pumpAndSettle();
      expect(find.text('KK-1'), findsOneWidget);

      await tester.tap(find.text('Pembayaran'));
      await tester.enterText(
          field('ticket-subject'), ' VA sudah dibayar tapi belum lunas ');
      await tester.enterText(
          field('ticket-message'), 'Sudah bayar VA BCA jam 10.');
      await tester.tap(find.text('Kirim Tiket'));
      await tester.pumpAndSettle();

      final post = h.server.where('POST', '/me/tickets').single;
      expect(jsonDecode(post.body), {
        'category': 'pembayaran',
        'subject': 'VA sudah dibayar tapi belum lunas',
        'message': 'Sudah bayar VA BCA jam 10.',
        'order_code': 'KK-1',
      });
      expect(find.byType(TicketCreateScreen), findsNothing);
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      expect(find.text('TK-20261113-NEW1'), findsOneWidget);
      expect(find.text('Sudah bayar VA BCA jam 10.'), findsOneWidget);
      expect(find.text('Pesanan terkait: KK-1'), findsOneWidget);
      expect(find.text('Menunggu admin'), findsOneWidget);
      // Kembali dari detail langsung ke layar sebelum formulir.
      Navigator.of(tester.element(find.byType(TicketDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('beranda'), findsOneWidget);
    });
  });

  group('detail tiket', () {
    testWidgets('utas: header, gelembung pembeli kanan & admin kiri',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');

      expect(h.server.where('GET', '/me/tickets/TK-1'), hasLength(1));
      expect(find.text('TK-1'), findsOneWidget);
      expect(find.text('VA sudah dibayar tapi status belum lunas'),
          findsOneWidget);
      expect(find.text('Kategori: Pembayaran'), findsOneWidget);
      expect(find.text('Pesanan terkait: KK-20261113-DC4T'), findsOneWidget);
      expect(find.text('Dibalas'), findsOneWidget);
      expect(find.text('Tim KateringKita'), findsOneWidget);
      expect(find.text(formatWib(DateTime.parse(_t1))), findsOneWidget);

      final mine = find.text('Sudah bayar VA BCA tapi masih menunggu.');
      final admin = find.text('Sudah kami cek, pembayaranmu masuk.');
      expect(tester.getCenter(mine).dx, greaterThan(400));
      expect(tester.getCenter(admin).dx, lessThan(400));
      expect(
          tester.widget<TextField>(find.byKey(const ValueKey('ticket-reply')))
              .enabled,
          isNot(false));
      expect(find.text('Tutup tiket'), findsOneWidget);
    });

    testWidgets('balas: validasi 1–2000, POST {body}, pesan baru tampil',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');
      final input = find.byKey(const ValueKey('ticket-reply'));

      await tester.enterText(input, '   ');
      await tester.tap(find.byKey(const ValueKey('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Pesan 1–2000 karakter.'), findsOneWidget);
      expect(h.server.where('POST', '/me/tickets/TK-1/messages'), isEmpty);

      await tester.enterText(input, ' Terima kasih, sudah lunas! ');
      await tester.pump();
      expect(find.text('Pesan 1–2000 karakter.'), findsNothing);
      expect(find.text('26/2000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ticket-send')));
      await tester.pumpAndSettle();
      final post = h.server.where('POST', '/me/tickets/TK-1/messages').single;
      expect(jsonDecode(post.body), {'body': 'Terima kasih, sudah lunas!'});
      expect(find.text('Terima kasih, sudah lunas!'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(find.text('Menunggu admin'), findsOneWidget);
    });

    testWidgets('tiket tertutup: kotak balas nonaktif + penjelasan',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] =
          _detail('TK-1', status: 'closed', closedBy: 'admin');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');
      expect(find.text('Ditutup'), findsOneWidget);
      expect(find.textContaining('Tiket ini sudah ditutup'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('ticket-reply')))
              .enabled,
          isFalse);
      expect(find.byKey(const ValueKey('ticket-send')), findsNothing);
      expect(find.text('Tutup tiket'), findsNothing);
      expect(
          find.text('Ditutup oleh Tim KateringKita: '
              '${formatWib(DateTime.parse(_t1))}'),
          findsOneWidget);

      await tester.tap(find.text('Buat tiket baru'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketCreateScreen), findsOneWidget);
    });

    testWidgets('409 TICKET_CLOSED saat membalas: pesan server, jadi tertutup',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');
      // Admin menutup tiket sementara layar terbuka.
      h.server.tickets['TK-1']!['status'] = 'closed';
      await tester.enterText(
          find.byKey(const ValueKey('ticket-reply')), 'Masih belum masuk');
      await tester.tap(find.byKey(const ValueKey('ticket-send')));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Tiket sudah ditutup. Buat tiket baru bila masih perlu bantuan.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-closed-bar')), findsOneWidget);
      expect(h.server.where('GET', '/me/tickets/TK-1'), hasLength(2));
    });

    testWidgets('Tutup tiket: konfirmasi dulu, Batal tidak mengirim',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');

      await tester.tap(find.text('Tutup tiket'));
      await tester.pumpAndSettle();
      expect(find.text('Tutup tiket ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(h.server.where('POST', '/me/tickets/TK-1/close'), isEmpty);

      await tester.tap(find.text('Tutup tiket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Tutup'));
      await tester.pumpAndSettle();
      expect(h.server.where('POST', '/me/tickets/TK-1/close'), hasLength(1));
      expect(find.text('Tiket ditutup.'), findsOneWidget);
      expect(find.text('Ditutup'), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-closed-bar')), findsOneWidget);
      expect(find.text('Tutup tiket'), findsNothing);
    });

    testWidgets('tarik untuk memuat ulang: balasan admin baru tampil',
        (tester) async {
      final h = _Harness();
      h.server.tickets['TK-1'] = _detail('TK-1');
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');
      h.server.tickets['TK-1']!['messages'] = [
        ...h.server.tickets['TK-1']!['messages'] as List,
        {
          'id': 3,
          'sender_role': 'admin',
          'sender_name': 'Tim KateringKita',
          'body': 'Ada lagi yang bisa kami bantu?',
          'created_at': _t1,
        },
      ];
      await tester.fling(find.text('Kategori: Pembayaran'),
          const Offset(0, 900), 1000);
      await tester.pumpAndSettle();
      expect(h.server.where('GET', '/me/tickets/TK-1'), hasLength(2));
      expect(find.text('Ada lagi yang bisa kami bantu?'), findsOneWidget);
    });

    testWidgets('404: pesan server + Coba Lagi', (tester) async {
      final h = _Harness();
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-X');
      expect(find.text('Tiket tidak ditemukan.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('balasan admin dibaca: titik Profil diperbarui',
        (tester) async {
      final h = _Harness();
      h.unread.setUnread(1);
      h.server
        ..tickets['TK-1'] = _detail('TK-1')
        ..unreadCount = 0;
      await h.open(tester, AppRoutes.ticketDetail, arguments: 'TK-1');
      expect(h.unread.unreadCount, 0);
    });
  });
}
