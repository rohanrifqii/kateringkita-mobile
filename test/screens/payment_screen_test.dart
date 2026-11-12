import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/screens/orders/payment_screen.dart';
import 'package:provider/provider.dart';

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  ApiUser? get user => null;
  @override
  bool get isLoggedIn => false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _order({
  String method = 'va',
  String status = 'holding',
  String payStatus = 'unpaid',
  int secondsLeft = 600,
  Map<String, dynamic>? payment,
}) =>
    {
      'code': 'KK-1',
      'status': status,
      'payment_method': method,
      'payment_status': payStatus,
      'hold_until': DateTime.now()
          .add(Duration(seconds: secondsLeft))
          .toUtc()
          .toIso8601String(),
      'seconds_left': secondsLeft,
      'pickup_point': {'id': 2, 'name': 'Perpustakaan Pusat'},
      'items': [
        {
          'menu_id': 7,
          'menu_name': 'Nasi Box',
          'qty': 2,
          'unit_price': 45000,
          'options': [],
          'line_total': 90000,
        }
      ],
      'subtotal': 90000,
      'discount': 0,
      'service_fee': 9000,
      'total': 99000,
      'created_at': '2026-11-12T03:00:00Z',
      'updated_at': '2026-11-12T03:00:00Z',
      'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62812'},
      'payment': ?payment,
    };

Map<String, dynamic> _va() => {
      'method': 'va',
      'status': 'pending',
      'amount': 99000,
      'va': {
        'bank': 'bca',
        'va_number': '8808123456789',
        'expires_at': '2026-11-12T04:00:00Z',
      },
    };

class _H {
  final reqs = <http.Request>[];
  String? snapUrl;
}

Future<_H> _open(
  WidgetTester tester, {
  required Map<String, dynamic> arg,
  required Future<http.Response> Function(http.Request r) handler,
}) async {
  final h = _H();
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    timeout: const Duration(seconds: 2),
    client: MockClient((req) async {
      h.reqs.add(req);
      return handler(req);
    }),
  );
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final order = OrderApiModel.fromJson(arg);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
    ],
    child: MaterialApp(
      routes: {
        AppRoutes.whatsappGenerator: (_) => const Scaffold(body: Text('WA')),
        AppRoutes.mainNav: (_) => const Scaffold(body: Text('MAIN')),
      },
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  settings: RouteSettings(arguments: order),
                  builder: (_) => PaymentScreen(
                    snapOpener: (ctx, url) async => h.snapUrl = url,
                  ),
                )),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('VA tanpa nomor: pilih bank -> POST /va lalu tampil va_number',
      (tester) async {
    final h = await _open(tester,
        arg: _order(),
        handler: (r) async {
          if (r.url.path.endsWith('/va')) {
            return _json({'data': _order(payment: _va())});
          }
          return _json({'data': _order()});
        });
    expect(find.text('Rp 99.000'), findsWidgets);
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(h.reqs.where((r) => r.url.path.endsWith('/va')), isEmpty);

    await tester.tap(find.text('BCA'));
    await tester.pump();
    await tester.tap(find.text('Buat Nomor Virtual Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final vaReq = h.reqs.where((r) => r.url.path.endsWith('/va')).toList();
    expect(vaReq.length, 1);
    expect(jsonDecode(vaReq.single.body), {'bank': 'bca'});
    expect(find.text('8808123456789'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('waktu habis: pesan kedaluwarsa, tanpa lembar sukses',
      (tester) async {
    await _open(tester,
        arg: _order(secondsLeft: 0),
        handler: (r) async => _json({'data': _order(secondsLeft: 0)}));
    expect(find.text('Batas waktu pesanan sudah habis.'), findsOneWidget);
    expect(find.textContaining('Pembayaran Berhasil'), findsNothing);
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('paid dari server: lembar sukses tampil', (tester) async {
    await _open(tester,
        arg: _order(payment: _va()),
        handler: (r) async => _json({
              'data': _order(
                  status: 'confirmed', payStatus: 'paid', payment: _va())
            }));
    // Poller 5 detik.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Pembayaran Berhasil'), findsOneWidget);
    expect(find.text('Kirim Rincian ke WhatsApp'), findsOneWidget);
    expect(find.text('Lihat Pesanan'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('belum paid: tidak ada lembar sukses', (tester) async {
    await _open(tester,
        arg: _order(payment: _va()),
        handler: (r) async => _json({'data': _order(payment: _va())}));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pembayaran Berhasil'), findsNothing);
    expect(find.text('8808123456789'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('online: startOnline lalu buka Snap lalu get(code)',
      (tester) async {
    final h = await _open(tester,
        arg: _order(method: 'online'),
        handler: (r) async {
          if (r.url.path.endsWith('/online')) {
            return _json({
              'data': _order(method: 'online', payment: {
                'method': 'online',
                'status': 'pending',
                'amount': 99000,
                'payment_url': 'https://app.sandbox.midtrans.com/snap/v4/x',
              })
            });
          }
          return _json({'data': _order(method: 'online')});
        });
    await tester.tap(find.text('Bayar dengan QRIS / E-Wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.snapUrl, 'https://app.sandbox.midtrans.com/snap/v4/x');
    final paths = h.reqs.map((r) => '${r.method} ${r.url.path}').toList();
    expect(paths.last, 'GET /api/v1/orders/KK-1');
    expect(paths.where((p) => p.endsWith('/online')).length, 1);
    await _close(tester);
  });
}
