import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/core/relative_time.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';
import 'package:kateringkita_pbl/providers/notification_provider.dart';
import 'package:kateringkita_pbl/screens/home/notification_screen.dart';
import 'package:kateringkita_pbl/widgets/notification_bell.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

Map<String, dynamic> _notif(int id,
        {String type = 'order_status',
        String title = 'Pesanan siap diambil',
        String body = 'Pesanan KK-1 sudah siap. Silakan ambil di titik temu.',
        Map<String, dynamic>? data,
        bool read = false,
        Duration ago = const Duration(minutes: 5)}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {'order_code': 'KK-1', 'status': 'ready'},
      'read_at': read ? _ago(const Duration(minutes: 1)) : null,
      'created_at': _ago(ago),
    };

Object _page(List<Map<String, dynamic>> items, {int? unread, int? total}) => {
      'data': items,
      'meta': {
        'page': 1,
        'limit': 20,
        'total': total ?? items.length,
        'unread_count':
            unread ?? items.where((e) => e['read_at'] == null).length,
      },
    };

final _sample = [
  _notif(3),
  _notif(2,
      type: 'promo',
      title: 'Promo baru dari Dapur A',
      body: 'Pakai kode HEMAT saat checkout.',
      data: {'promo_code': 'HEMAT', 'merchant_id': 1},
      ago: const Duration(hours: 2)),
  _notif(1,
      type: 'info',
      title: 'Jadwal libur',
      body: 'Layanan libur tanggal merah.',
      data: {'audience': 'all'},
      read: true,
      ago: const Duration(days: 3)),
];

class _Harness {
  _Harness(this.handler, {FakeAuth? auth})
      : auth = auth ?? FakeAuth(loggedIn: true) {
    final api = ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) {
          requests.add(req);
          return handler(req);
        }));
    notifications = NotificationProvider(NotificationRepository(api));
    providers = sessionProviders(api,
        auth: this.auth, notifications: notifications);
  }

  final Future<http.Response> Function(http.Request) handler;
  final FakeAuth auth;
  final requests = <http.Request>[];
  late final NotificationProvider notifications;
  late final List<SingleChildWidget> providers;
  Object? trackingArgs;
  Object? ticketArgs;

  Widget app(Widget home) => MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: home,
          routes: {
            AppRoutes.orderTracking: (c) {
              trackingArgs = ModalRoute.of(c)?.settings.arguments;
              return const Scaffold(body: Text('layar-lacak'));
            },
            AppRoutes.ticketDetail: (c) {
              ticketArgs = ModalRoute.of(c)?.settings.arguments;
              return const Scaffold(body: Text('layar-tiket'));
            },
            AppRoutes.login: (_) => const Scaffold(body: Text('layar-login')),
            AppRoutes.notifications: (_) => const NotificationScreen(),
          },
        ),
      );

  Iterable<http.Request> posts() => requests.where((r) => r.method == 'POST');
}

void main() {
  testWidgets('tamu: ajakan masuk tanpa permintaan', (tester) async {
    final h = _Harness((req) async => _json(_page([])), auth: FakeAuth());
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk melihat notifikasi'), findsOneWidget);
    expect(h.requests, isEmpty);
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('layar-login'), findsOneWidget);
  });

  testWidgets('daftar dari server: judul, isi, waktu relatif, belum dibaca',
      (tester) async {
    final h = _Harness((req) async => _json(_page(_sample, unread: 7)));
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();

    expect(h.requests.single.url.path, '/api/v1/me/notifications');
    expect(find.text('Pesanan siap diambil'), findsOneWidget);
    expect(find.text('Pesanan KK-1 sudah siap. Silakan ambil di titik temu.'),
        findsOneWidget);
    expect(find.text('5 menit lalu'), findsOneWidget);
    // 2 jam lalu bisa saja sudah "Kemarin" di WIB; ikuti aturan yang sama.
    String rel(Map<String, dynamic> n) =>
        relativeTimeWib(DateTime.parse(n['created_at'] as String));
    expect(find.text(rel(_sample[1])), findsOneWidget);
    expect(find.text('3 hari lalu'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-1')), findsNothing);
    // unread_count dari meta (bukan hanya halaman ini) dipakai lencana.
    expect(h.notifications.unreadCount, 7);
    expect(find.text('Tandai Dibaca'), findsOneWidget);
  });

  group('filter tipe di server', () {
    /// Server palsu yang menyaring `type` seperti backend.
    Future<http.Response> server(http.Request req) async {
      final type = req.url.queryParameters['type'];
      final items = [
        for (final n in _sample)
          if (type == null || n['type'] == type) n
      ];
      return _json(_page(items, unread: 9));
    }

    List<Map<String, String>> queries(_Harness h) => [
          for (final r in h.requests.where((r) => r.method == 'GET'))
            r.url.queryParameters
        ];

    testWidgets('chip memuat ulang dengan type; Semua tanpa type',
        (tester) async {
      final h = _Harness(server);
      await tester.pumpWidget(h.app(const NotificationScreen()));
      await tester.pumpAndSettle();
      expect(queries(h).single.containsKey('type'), isFalse);

      await tester.tap(find.text('Promo'));
      await tester.pumpAndSettle();
      expect(queries(h).last, {'page': '1', 'limit': '20', 'type': 'promo'});
      expect(find.text('Promo baru dari Dapur A'), findsOneWidget);
      expect(find.text('Pesanan siap diambil'), findsNothing);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(queries(h).last['type'], 'info');
      expect(find.text('Jadwal libur'), findsOneWidget);

      await tester.tap(find.text('Pesanan'));
      await tester.pumpAndSettle();
      expect(queries(h).last['type'], 'order_status');
      expect(find.text('Pesanan siap diambil'), findsOneWidget);
      expect(find.text('Jadwal libur'), findsNothing);

      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();
      expect(queries(h).last.containsKey('type'), isFalse);
      expect(find.text('Jadwal libur'), findsOneWidget);
      // unread_count tetap global dari meta.
      expect(h.notifications.unreadCount, 9);
    });

    testWidgets('chip yang sama tidak memuat ulang', (tester) async {
      final h = _Harness(server);
      await tester.pumpWidget(h.app(const NotificationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();
      expect(queries(h), hasLength(1));
    });

    testWidgets('kosong per tipe: pesan kategori', (tester) async {
      final h = _Harness((req) async {
        if (req.url.queryParameters['type'] == 'promo') {
          return _json(_page([], unread: 2));
        }
        return server(req);
      });
      await tester.pumpWidget(h.app(const NotificationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promo'));
      await tester.pumpAndSettle();
      expect(find.text('Kategori "Promo" saat ini kosong.'), findsOneWidget);
      expect(find.text('Pesanan siap diambil'), findsNothing);
    });

    testWidgets('muat lebih banyak menghormati filter', (tester) async {
      final h = _Harness((req) async {
        final q = req.url.queryParameters;
        if (q['type'] != 'promo') return _json(_page(_sample));
        if (q['page'] == '2') {
          return _json(_page([
            _notif(20,
                type: 'promo',
                title: 'Promo lama',
                data: {'promo_code': 'LAMA'})
          ], total: 2));
        }
        return _json(_page([
          _notif(21,
              type: 'promo', title: 'Promo baru', data: {'promo_code': 'B'})
        ], total: 2));
      });
      await tester.pumpWidget(h.app(const NotificationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();
      expect(queries(h).last, {'page': '2', 'limit': '20', 'type': 'promo'});
      expect(find.text('Promo baru'), findsOneWidget);
      expect(find.text('Promo lama'), findsOneWidget);
      expect(find.text('Muat lebih banyak'), findsNothing);
    });

    testWidgets('jawaban chip lama yang terlambat diabaikan', (tester) async {
      final slow = Completer<void>();
      final h = _Harness((req) async {
        final type = req.url.queryParameters['type'];
        if (type == 'promo') {
          await slow.future;
          return _json(_page([
            _notif(30, type: 'promo', title: 'Promo telat', data: {})
          ]));
        }
        return server(req);
      });
      await tester.pumpWidget(h.app(const NotificationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promo'));
      await tester.pump();
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.text('Jadwal libur'), findsOneWidget);
      expect(find.text('Promo telat'), findsNothing);
    });
  });

  testWidgets(
      'ketuk notifikasi pesanan: ditandai dibaca, buka Pesanan tab & kode',
      (tester) async {
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        return _json({
          'data': {'unread_count': 1}
        });
      }
      return _json(_page(_sample));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    expect(h.notifications.unreadCount, 2);

    await tester.tap(find.text('Pesanan siap diambil'));
    await tester.pumpAndSettle();
    final post = h.posts().single;
    expect(post.url.path, '/api/v1/me/notifications/read');
    expect(jsonDecode(post.body), {
      'ids': [3]
    });
    expect(find.text('layar-lacak'), findsOneWidget);
    expect(h.trackingArgs, 'KK-1');
    expect(h.notifications.unreadCount, 1);

    Navigator.of(tester.element(find.text('layar-lacak'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-3')), findsNothing);
  });

  testWidgets('notifikasi tiket (data.ticket_code): dibaca, buka detail tiket',
      (tester) async {
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        return _json({
          'data': {'unread_count': 0}
        });
      }
      return _json(_page([
        _notif(11,
            type: 'info',
            title: 'Balasan tiket TK-20261113-7QPX',
            body: 'Tim KateringKita membalas "VA belum lunas".',
            data: {'ticket_code': 'TK-20261113-7QPX'}),
        _notif(10,
            type: 'info',
            title: 'Jadwal libur',
            body: 'Layanan libur tanggal merah.',
            data: {'audience': 'all'}),
      ]));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balasan tiket TK-20261113-7QPX'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.posts().single.body), {
      'ids': [11]
    });
    expect(find.text('layar-tiket'), findsOneWidget);
    expect(h.ticketArgs, 'TK-20261113-7QPX');
    expect(h.trackingArgs, isNull);

    // Info biasa tanpa ticket_code tidak pindah layar.
    Navigator.of(tester.element(find.text('layar-tiket'))).pop();
    await tester.pumpAndSettle();
    h.ticketArgs = null;
    await tester.tap(find.text('Jadwal libur'));
    await tester.pumpAndSettle();
    expect(find.text('layar-tiket'), findsNothing);
    expect(h.ticketArgs, isNull);
  });

  testWidgets('pesanan dibatalkan juga membuka Lacak Pesanan', (tester) async {
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        return _json({
          'data': {'unread_count': 0}
        });
      }
      return _json(_page([
        _notif(9,
            title: 'Pesanan ditolak',
            data: {'order_code': 'KK-9', 'status': 'cancelled'}),
      ]));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesanan ditolak'));
    await tester.pumpAndSettle();
    expect(h.trackingArgs, 'KK-9');
  });

  testWidgets('notifikasi promo hanya ditandai dibaca, tidak pindah layar',
      (tester) async {
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        return _json({
          'data': {'unread_count': 1}
        });
      }
      return _json(_page(_sample));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Promo baru dari Dapur A'));
    await tester.pumpAndSettle();
    expect(h.posts().length, 1);
    expect(find.text('layar-lacak'), findsNothing);
    expect(find.byKey(const ValueKey('unread-2')), findsNothing);
  });

  testWidgets('tandai dibaca gagal: kembali belum dibaca', (tester) async {
    final gate = Completer<void>();
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        await gate.future;
        return _json({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'x'}
        }, 500);
      }
      return _json(_page(_sample));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Promo baru dari Dapur A'));
    await tester.pump();
    expect(find.byKey(const ValueKey('unread-2')), findsNothing);
    expect(h.notifications.unreadCount, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-2')), findsOneWidget);
    expect(h.notifications.unreadCount, 2);
  });

  testWidgets('Tandai Dibaca: POST {all:true}, semua jadi dibaca',
      (tester) async {
    final h = _Harness((req) async {
      if (req.method == 'POST') {
        return _json({
          'data': {'unread_count': 0}
        });
      }
      return _json(_page(_sample));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tandai Dibaca'));
    await tester.pumpAndSettle();
    expect(jsonDecode(h.posts().single.body), {'all': true});
    expect(find.byKey(const ValueKey('unread-3')), findsNothing);
    expect(find.byKey(const ValueKey('unread-2')), findsNothing);
    expect(find.text('Semua notifikasi telah ditandai sudah dibaca'),
        findsOneWidget);
    expect(find.text('Tandai Dibaca'), findsNothing);
    expect(h.notifications.unreadCount, 0);
  });

  testWidgets('kosong dan galat + Coba Lagi', (tester) async {
    var calls = 0;
    final h = _Harness((req) async {
      calls++;
      if (calls == 1) {
        return _json({
          'error': {'code': 'NETWORK', 'message': 'Server sibuk.'}
        }, 503);
      }
      return _json(_page([]));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Server sibuk.'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada notifikasi'), findsOneWidget);
    expect(find.text('Tandai Dibaca'), findsNothing);
  });

  testWidgets('muat lebih banyak saat total > yang dimuat', (tester) async {
    final h = _Harness((req) async {
      final page = req.url.queryParameters['page'];
      if (page == '2') {
        return _json(_page([_notif(1, title: 'Lama sekali')], total: 2));
      }
      return _json(_page([_notif(2)], total: 2));
    });
    await tester.pumpWidget(h.app(const NotificationScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Lama sekali'), findsNothing);
    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();
    expect(find.text('Lama sekali'), findsOneWidget);
    expect(find.text('Muat lebih banyak'), findsNothing);
  });

  group('lonceng beranda', () {
    testWidgets('pembeli: lencana unread_count, buka layar Notifikasi',
        (tester) async {
      final h = _Harness((req) async {
        if (req.url.queryParameters['unread'] == 'true') {
          return _json(_page([_notif(3)], unread: 12));
        }
        return _json(_page(_sample, unread: 12));
      });
      await tester.pumpWidget(
          h.app(const Scaffold(body: Center(child: NotificationBell()))));
      await tester.pumpAndSettle();
      final q = h.requests.first.url.queryParameters;
      expect(q['unread'], 'true');
      expect(q['limit'], '1');
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
    });

    testWidgets('lebih dari 99 ditampilkan 99+', (tester) async {
      final h =
          _Harness((req) async => _json(_page([_notif(3)], unread: 120)));
      await tester.pumpWidget(
          h.app(const Scaffold(body: Center(child: NotificationBell()))));
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('tamu: tanpa permintaan & tanpa lencana; login memuat',
        (tester) async {
      final auth = FakeAuth();
      final h = _Harness((req) async => _json(_page([_notif(3)], unread: 4)),
          auth: auth);
      await tester.pumpWidget(
          h.app(const Scaffold(body: Center(child: NotificationBell()))));
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      expect(find.text('4'), findsNothing);

      auth.set(true);
      await tester.pumpAndSettle();
      expect(h.requests, hasLength(1));
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('diperbarui berkala selama terlihat', (tester) async {
      var n = 1;
      final h = _Harness(
          (req) async => _json(_page([_notif(3)], unread: n)));
      await tester.pumpWidget(
          h.app(const Scaffold(body: Center(child: NotificationBell()))));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      n = 5;
      await tester.pump(NotificationBell.pollInterval);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
    });
  });
}
