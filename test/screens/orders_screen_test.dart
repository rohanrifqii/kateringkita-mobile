import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';
import 'package:kateringkita_pbl/data/order_chat_repository.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/providers/notification_provider.dart';
import 'package:kateringkita_pbl/screens/orders/orders_screen.dart';
import 'package:kateringkita_pbl/widgets/order_status_label.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth(this.loggedIn);
  bool loggedIn;
  @override
  bool get isLoggedIn => loggedIn;
  void set(bool v) {
    loggedIn = v;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _order(String code,
        {String status = 'confirmed',
        String pay = 'paid',
        bool cancel = false,
        bool complete = false,
        int? secondsLeft}) =>
    {
      'code': code,
      'status': status,
      'payment_method': 'va',
      'payment_status': pay,
      'seconds_left': secondsLeft,
      'pickup_point': {'id': 1, 'name': 'Gerbang', 'description': ''},
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Nasi Box',
          'qty': 2,
          'unit_price': 20000,
          'options': [],
          'line_total': 40000
        },
        {
          'menu_id': 8,
          'menu_name': 'Es Teh',
          'qty': 1,
          'unit_price': 5000,
          'options': [],
          'line_total': 5000
        },
      ],
      'subtotal': 45000,
      'discount': 0,
      'service_fee': 0,
      'total': 45000,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62'},
      'can_cancel': cancel,
      'can_complete': complete,
      'can_review': false,
    };

Widget _wrap(
  Future<http.Response> Function(http.Request) handler, {
  bool loggedIn = true,
  _FakeAuth? auth,
  CartProvider? cart,
  Map<String, WidgetBuilder> routes = const {},
  Widget home = const OrdersScreen(),
  NotificationProvider? notifications,
}) {
  final api = ApiClient(
      baseUrl: 'https://x.test/api/v1', client: MockClient(handler));
  return MultiProvider(
    providers: [
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      ChangeNotifierProvider<CartProvider>.value(value: cart ?? CartProvider()),
      ChangeNotifierProvider<AuthProvider>.value(
          value: auth ?? _FakeAuth(loggedIn)),
      if (notifications != null)
        ChangeNotifierProvider<NotificationProvider>.value(
            value: notifications),
    ],
    child: MaterialApp(home: home, routes: routes),
  );
}

void main() {
  testWidgets('dibuka dari notifikasi: tab & kode pesanan awal dipakai',
      (tester) async {
    final seen = <Uri>[];
    await tester.pumpWidget(_wrap((req) async {
      seen.add(req.url);
      return _json({'data': [], 'meta': {'total': 0}});
    }, home: const OrdersScreen(initialTab: 'cancelled', initialQuery: 'KK-9')));
    await tester.pumpAndSettle();
    expect(seen.first.queryParameters['tab'], 'cancelled');
    expect(seen.first.queryParameters['q'], 'KK-9');
    expect(find.widgetWithText(TextField, 'KK-9'), findsOneWidget);
  });

  testWidgets('memuat ulang daftar juga menyegarkan badge chat tab Pesanan',
      (tester) async {
    // Server badge terpisah: total chat belum dibaca bisa diubah test.
    var chatUnreadTotal = 3;
    final badgeApi = ApiClient(
      baseUrl: 'https://x.test/api/v1',
      client: MockClient((req) async => req.url.path.endsWith('/me/chats/unread')
          ? _json({
              'data': {'total': chatUnreadTotal}
            })
          : _json({}, 404)),
    );
    final notifications = NotificationProvider(
      NotificationRepository(badgeApi),
      chatRepository: OrderChatRepository(badgeApi),
    );
    await tester.pumpWidget(_wrap(
      (req) async => _json({
        'data': [_order('KK-1')],
        'meta': {'total': 1}
      }),
      notifications: notifications,
    ));
    await tester.pumpAndSettle();
    expect(notifications.chatUnreadCount, 3);

    // Cek berkala daftar (15 detik) ikut memperbarui badge.
    chatUnreadTotal = 5;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(notifications.chatUnreadCount, 5);
  });

  testWidgets('ketuk kartu pesanan membuka Lacak Pesanan dengan kodenya',
      (tester) async {
    await tester.pumpWidget(_wrap(
      (req) async => _json({
        'data': [_order('KK-1')],
        'meta': {'total': 1}
      }),
      routes: {
        // Kode pesanan ada di alamat rute.
        AppRoutes.orderTrackingFor('KK-1'): (_) =>
            const Scaffold(body: Text('layar-lacak')),
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nasi Box +1 menu lain'));
    await tester.pumpAndSettle();
    expect(find.text('layar-lacak'), findsOneWidget);
  });

  testWidgets('kartu menampilkan jumlah chat belum dibaca dari chat.unread_count',
      (tester) async {
    Map<String, dynamic> withUnread(String code, int unread) => {
          ..._order(code),
          'chat': {
            'available': true,
            'is_open': true,
            'closed_reason': null,
            'unread_count': unread,
            'other_party_last_read_id': null,
            'reported_by_me': false,
          },
        };
    await tester.pumpWidget(_wrap((req) async => _json({
          'data': [withUnread('KK-1', 2), withUnread('KK-2', 0)],
          'meta': {'total': 2}
        })));
    await tester.pumpAndSettle();
    expect(find.text('2 pesan baru'), findsOneWidget);
    expect(find.textContaining('pesan baru'), findsOneWidget);
  });

  testWidgets('tab Aktif memuat ?tab=active; tombol sesuai can_cancel/complete',
      (tester) async {
    final seen = <Uri>[];
    await tester.pumpWidget(_wrap((req) async {
      seen.add(req.url);
      return _json({
        'data': [
          _order('KK-1', cancel: true),
          _order('KK-2', complete: true),
        ],
        'meta': {'total': 2}
      });
    }));
    await tester.pumpAndSettle();

    expect(seen.first.queryParameters['tab'], 'active');
    expect(find.text('KK-1'), findsOneWidget);
    expect(find.text('Nasi Box +1 menu lain'), findsNWidgets(2));
    expect(find.text('Batalkan'), findsOneWidget);
    expect(find.text('Selesaikan Pesanan'), findsOneWidget);
    expect(find.text('Dikonfirmasi'), findsNWidgets(2));
  });

  testWidgets('Beri Ulasan hanya bila can_review; sukses memuat ulang daftar',
      (tester) async {
    var reviewed = false;
    var listCalls = 0;
    await tester.pumpWidget(_wrap((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/KK-1/reviews')) {
        reviewed = true;
        return _json({
          'data': {
            'order_code': 'KK-1',
            'reviewed_menu_ids': [7]
          }
        }, 201);
      }
      listCalls++;
      return _json({
        'data': [
          _order('KK-1', status: 'completed')..['can_review'] = !reviewed,
          _order('KK-2', status: 'completed'),
        ],
        'meta': {'total': 2}
      });
    }));
    await tester.pumpAndSettle();
    expect(find.text('Beri Ulasan'), findsOneWidget);

    await tester.tap(find.text('Beri Ulasan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-7-5')));
    await tester.pump();
    await tester.tap(find.text('Kirim Ulasan'));
    await tester.pumpAndSettle();

    expect(reviewed, true);
    expect(listCalls, greaterThanOrEqualTo(2));
    expect(find.text('Beri Ulasan'), findsNothing);
  });

  testWidgets('batal sukses memuat ulang daftar', (tester) async {
    var listCalls = 0;
    var cancelled = false;
    await tester.pumpWidget(_wrap((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/KK-1/cancel')) {
        cancelled = true;
        return _json({'data': _order('KK-1', status: 'cancelled')});
      }
      listCalls++;
      return _json({
        'data': cancelled ? [] : [_order('KK-1', cancel: true)],
        'meta': {'total': cancelled ? 0 : 1}
      });
    }));
    await tester.pumpAndSettle();
    expect(listCalls, 1);

    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(listCalls, greaterThanOrEqualTo(2));
    expect(find.text('KK-1'), findsNothing);
  });

  testWidgets('tamu: ajakan masuk tanpa request', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap((req) async {
      calls++;
      return _json({'data': [], 'meta': {'total': 0}});
    }, loggedIn: false));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('tamu lalu login di tempat lain: daftar langsung dimuat',
      (tester) async {
    final auth = _FakeAuth(false);
    var calls = 0;
    await tester.pumpWidget(_wrap((req) async {
      calls++;
      return _json({
        'data': [_order('KK-1')],
        'meta': {'total': 1}
      });
    }, auth: auth));
    await tester.pumpAndSettle();
    expect(calls, 0);

    auth.set(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(find.text('KK-1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Keluar: daftar milik akun sebelumnya tidak tersisa.
    auth.set(false);
    await tester.pump();
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('KK-1'), findsNothing);
  });

  test('orderStatusLabel', () {
    String l(String status, {String pay = 'paid', String? by}) {
      final j = _order('X', status: status, pay: pay);
      j['cancelled_by'] = by;
      return orderStatusLabel(OrderApiModel.fromJson(j));
    }

    expect(l('holding', pay: 'unpaid'), 'Menunggu pembayaran');
    expect(l('confirmed'), 'Dikonfirmasi');
    expect(l('cooking'), 'Sedang dimasak');
    expect(l('ready'), 'Siap diambil');
    expect(l('completed'), 'Selesai');
    expect(l('cancelled'), 'Dibatalkan');
    expect(l('cancelled', by: 'merchant'), 'Dibatalkan oleh penjual');
    expect(l('cancelled', by: 'system'), 'Dibatalkan oleh sistem');
    expect(l('expired'), 'Kedaluwarsa');
  });

  testWidgets('batal: "Tidak" tidak mengirim request', (tester) async {
    var posts = 0;
    await tester.pumpWidget(_wrap((req) async {
      if (req.method == 'POST') posts++;
      return _json({
        'data': [_order('KK-1', cancel: true)],
        'meta': {'total': 1}
      });
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan pesanan?'), findsOneWidget);
    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(posts, 0);
  });

  testWidgets('ganti query saat poll berjalan: hanya hasil query baru',
      (tester) async {
    final oldPoll = Completer<http.Response>();
    var calls = 0;
    await tester.pumpWidget(_wrap((req) async {
      calls++;
      final q = req.url.queryParameters['q'];
      if (q == 'baru') {
        return _json({
          'data': [_order('KK-BARU')],
          'meta': {'total': 1}
        });
      }
      if (calls == 2) return oldPoll.future; // poll 15 dtk
      return _json({
        'data': [_order('KK-LAMA')],
        'meta': {'total': 1}
      });
    }));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15)); // poll menggantung
    await tester.enterText(find.byType(TextField), 'baru');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    oldPoll.complete(_json({
      'data': [_order('KK-LAMA')],
      'meta': {'total': 1}
    }));
    await tester.pumpAndSettle();
    expect(find.text('KK-BARU'), findsOneWidget);
    expect(find.text('KK-LAMA'), findsNothing);
  });

  group('pesan lagi', () {
    Map<String, dynamic> menu(int id, {List<int> opts = const []}) => {
          'id': id,
          'name': 'M$id',
          'price': 1000,
          'badge': 'available',
          'available': 5,
          'merchant': {
            'id': 1,
            'slug': 'a',
            'business_name': 'A',
            'is_open': true,
            'open_time': '08:00',
            'close_time': '17:00',
            'pickup_points': [],
          },
          'options': [
            for (final i in opts) {'id': i, 'name': 'O$i', 'extra_price': 0}
          ],
        };

    Future<http.Response> Function(http.Request) handler(
            {required List<Map<String, dynamic>> items,
            bool failSecond = false,
            List<int> menu7Opts = const []}) =>
        (req) async {
          final p = req.url.path;
          if (p.endsWith('/reorder')) {
            return _json({
              'data': {
                'request': {'items': items},
                'quote': {
                  'subtotal': 0,
                  'discount': 0,
                  'service_fee': 0,
                  'total': 0
                }
              }
            });
          }
          if (p.endsWith('/menus/7')) {
            return _json({'data': menu(7, opts: menu7Opts)});
          }
          if (p.endsWith('/menus/8')) {
            return failSecond
                ? _json({
                    'error': {'code': 'X', 'message': 'Menu gagal dimuat'}
                  }, 500)
                : _json({'data': menu(8)});
          }
          return _json({
            'data': [_order('KK-1', status: 'completed')],
            'meta': {'total': 1}
          });
        };

    Future<void> openCompleted(WidgetTester t) async {
      await t.pumpAndSettle();
      await t.pumpAndSettle();
    }

    testWidgets('menuDetail kedua gagal: keranjang tidak berubah',
        (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_wrap(
        handler(items: [
          {'menu_id': 7, 'qty': 1, 'option_ids': []},
          {'menu_id': 8, 'qty': 1, 'option_ids': []},
        ], failSecond: true),
        cart: cart,
        routes: {AppRoutes.checkout: (_) => const Text('CHECKOUT')},
      ));
      await openCompleted(tester);
      await tester.tap(find.text('Pesan Lagi'));
      await tester.pumpAndSettle();
      expect(cart.items, isEmpty);
      expect(find.text('CHECKOUT'), findsNothing);
      expect(find.text('Menu gagal dimuat'), findsOneWidget);
    });

    testWidgets('opsi hilang: pesan, tanpa navigasi, keranjang utuh',
        (tester) async {
      final cart = CartProvider();
      await tester.pumpWidget(_wrap(
        handler(items: [
          {'menu_id': 7, 'qty': 1, 'option_ids': [99]},
        ]),
        cart: cart,
        routes: {AppRoutes.checkout: (_) => const Text('CHECKOUT')},
      ));
      await openCompleted(tester);
      await tester.tap(find.text('Pesan Lagi'));
      await tester.pumpAndSettle();
      expect(cart.items, isEmpty);
      expect(find.text('CHECKOUT'), findsNothing);
      expect(find.textContaining('sudah tidak tersedia'), findsOneWidget);
    });

    ProductModel product(int id, int merchant) =>
        ProductModel.fromJson(menu(id)..['merchant']['id'] = merchant);

    testWidgets('keranjang toko lain: "Tidak" membiarkan keranjang',
        (tester) async {
      final cart = CartProvider()..add(product(50, 2), qty: 3);
      var reorderCalls = 0;
      final h = handler(items: [
        {'menu_id': 7, 'qty': 1, 'option_ids': []},
      ]);
      await tester.pumpWidget(_wrap(
        (req) {
          if (req.url.path.endsWith('/reorder')) reorderCalls++;
          return h(req);
        },
        cart: cart,
        routes: {AppRoutes.checkout: (_) => const Text('CHECKOUT')},
      ));
      await openCompleted(tester);
      await tester.tap(find.text('Pesan Lagi'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Keranjang berisi menu dari toko lain. Kosongkan dan ganti?'),
          findsOneWidget);
      await tester.tap(find.text('Tidak'));
      await tester.pumpAndSettle();
      expect(cart.items.single.menu.id, 50);
      expect(cart.items.single.qty, 3);
      expect(reorderCalls, 0);
      expect(find.text('CHECKOUT'), findsNothing);
    });

    testWidgets('keranjang toko sama: tanya dulu, "Ya" mengganti isi',
        (tester) async {
      final cart = CartProvider()..add(product(50, 1));
      await tester.pumpWidget(_wrap(
        handler(items: [
          {'menu_id': 7, 'qty': 2, 'option_ids': []},
        ]),
        cart: cart,
        routes: {AppRoutes.checkout: (_) => const Text('CHECKOUT')},
      ));
      await openCompleted(tester);
      await tester.tap(find.text('Pesan Lagi'));
      await tester.pumpAndSettle();
      expect(
          find.text('Keranjang akan diganti dengan isi pesanan ini. Lanjutkan?'),
          findsOneWidget);
      await tester.tap(find.text('Ya'));
      await tester.pumpAndSettle();
      expect(cart.items.single.menu.id, 7);
      expect(cart.items.single.qty, 2);
      expect(find.text('CHECKOUT'), findsOneWidget);
    });
  });
}
