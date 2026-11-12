import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
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
}) {
  final api = ApiClient(
      baseUrl: 'https://x.test/api/v1', client: MockClient(handler));
  return MultiProvider(
    providers: [
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(loggedIn)),
    ],
    child: const MaterialApp(home: OrdersScreen()),
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

    expect(cancelled, isTrue);
    expect(listCalls, 2);
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
}
