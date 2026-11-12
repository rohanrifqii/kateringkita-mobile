import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/orders/orders_screen.dart';
import 'package:kateringkita_pbl/widgets/order_status_label.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth(this.loggedIn);
  final bool loggedIn;
  @override
  bool get isLoggedIn => loggedIn;
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
  CartProvider? cart,
  Map<String, WidgetBuilder> routes = const {},
}) {
  final api = ApiClient(
      baseUrl: 'https://x.test/api/v1', client: MockClient(handler));
  return MultiProvider(
    providers: [
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      ChangeNotifierProvider<CartProvider>.value(value: cart ?? CartProvider()),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(loggedIn)),
    ],
    child: MaterialApp(home: const OrdersScreen(), routes: routes),
  );
}

void main() {
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
  });
}
