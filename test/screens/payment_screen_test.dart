import 'dart:async';
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

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _order({
  String method = 'va',
  String status = 'holding',
  String payStatus = 'unpaid',
  int secondsLeft = 600,
  String updatedAt = "2026-11-12T03:00:00Z",
  Map<String, dynamic>? payment,
}) => {
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
    },
  ],
  'subtotal': 90000,
  'discount': 0,
  'service_fee': 9000,
  'total': 99000,
  'created_at': '2026-11-12T03:00:00Z',
  'updated_at': updatedAt,
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
  Future<void> Function()? opener,
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
  await tester.pumpWidget(
    MultiProvider(
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
                    snapOpener: (ctx, url) async {
                      h.snapUrl = url;
                      if (opener != null) await opener();
                    },
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Status paid tetap: banner diterima tampil, hitung mundur tidak.
void _expectPaidBanner() {
  expect(find.text('Pembayaran sudah diterima.'), findsOneWidget);
  expect(find.text('Selesaikan pembayaran sebelum waktu habis'), findsNothing);
}

void main() {
  testWidgets('VA tanpa nomor: pilih bank -> POST /va lalu tampil va_number', (
    tester,
  ) async {
    final h = await _open(
      tester,
      arg: _order(),
      handler: (r) async {
        if (r.url.path.endsWith('/va')) {
          return _json({'data': _order(payment: _va())});
        }
        return _json({'data': _order()});
      },
    );
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

  testWidgets('waktu habis: pesan kedaluwarsa, tanpa lembar sukses', (
    tester,
  ) async {
    await _open(
      tester,
      arg: _order(secondsLeft: 0),
      handler: (r) async => _json({'data': _order(secondsLeft: 0)}),
    );
    expect(find.text('Batas waktu pesanan sudah habis.'), findsOneWidget);
    expect(find.textContaining('Pembayaran Berhasil'), findsNothing);
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('paid dari server: lembar sukses tampil', (tester) async {
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async => _json({
        'data': _order(status: 'confirmed', payStatus: 'paid', payment: _va()),
      }),
    );
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
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async => _json({'data': _order(payment: _va())}),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Pembayaran Berhasil'), findsNothing);
    expect(find.text('8808123456789'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('online: startOnline lalu buka Snap lalu get(code)', (
    tester,
  ) async {
    final h = await _open(
      tester,
      arg: _order(method: 'online'),
      handler: (r) async {
        if (r.url.path.endsWith('/online')) {
          return _json({
            'data': _order(
              method: 'online',
              payment: {
                'method': 'online',
                'status': 'pending',
                'amount': 99000,
                'payment_url': 'https://app.sandbox.midtrans.com/snap/v4/x',
              },
            ),
          });
        }
        return _json({'data': _order(method: 'online')});
      },
    );
    await tester.tap(find.text('Bayar dengan QRIS / E-Wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.snapUrl, 'https://app.sandbox.midtrans.com/snap/v4/x');
    final paths = h.reqs.map((r) => '${r.method} ${r.url.path}').toList();
    expect(paths.last, 'GET /api/v1/orders/KK-1');
    expect(paths.where((p) => p.endsWith('/online')).length, 1);
    await _close(tester);
  });

  testWidgets(
    'seconds_left 0 di argumen tapi server masih holding: bukan expired',
    (tester) async {
      await _open(
        tester,
        arg: _order(secondsLeft: 0, payment: _va()),
        handler: (r) async =>
            _json({'data': _order(secondsLeft: 30, payment: _va())}),
      );
      expect(find.text('Batas waktu pesanan sudah habis.'), findsNothing);
      expect(find.text('8808123456789'), findsOneWidget);
      expect(find.text('00:00:30'), findsOneWidget);
      await _close(tester);
    },
  );

  testWidgets('hitung mundur nol tapi server waiting: memeriksa status', (
    tester,
  ) async {
    final stale = _order(secondsLeft: 1, payment: _va())
      ..['seconds_left'] = null
      ..['hold_until'] = '2020-01-01T00:00:00Z';
    await _open(tester,
        arg: _order(secondsLeft: 2, payment: _va()),
        handler: (r) async => _json({'data': stale}));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Memeriksa status pembayaran'), findsOneWidget);
    expect(find.text('Batas waktu pesanan sudah habis.'), findsNothing);
    expect(find.text('8808123456789'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('respons usang tidak membatalkan status paid', (tester) async {
    var n = 0;
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async {
        n++;
        if (n == 1) return _json({'data': _order(payment: _va())});
        if (n == 2) {
          return _json({
            'data': _order(
              status: 'confirmed',
              payStatus: 'paid',
              payment: _va(),
              updatedAt: '2026-11-12T03:05:00Z',
            ),
          });
        }
        return _json({'data': _order(payment: _va())});
      },
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Pembayaran Berhasil'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(n, greaterThanOrEqualTo(3));
    expect(find.textContaining('Pembayaran Berhasil'), findsOneWidget);
    _expectPaidBanner();
    await _close(tester);
  });

  testWidgets('guard isPaid: unpaid terlambat dengan updatedAt lebih baru '
      'tidak membatalkan paid', (tester) async {
    var n = 0;
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async {
        n++;
        if (n == 1) return _json({'data': _order(payment: _va())});
        if (n == 2) {
          return _json({
            'data': _order(
              status: 'confirmed',
              payStatus: 'paid',
              payment: _va(),
              updatedAt: '2026-11-12T03:05:00Z',
            ),
          });
        }
        // Lebih baru dari respons paid, tetapi unpaid (mis. replika usang).
        return _json({
          'data': _order(payment: _va(), updatedAt: '2026-11-12T03:10:00Z'),
        });
      },
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    _expectPaidBanner();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(n, greaterThanOrEqualTo(3));
    _expectPaidBanner();
    await _close(tester);
  });

  testWidgets('guard updatedAt: unpaid lama setelah unpaid baru diabaikan', (
    tester,
  ) async {
    var n = 0;
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async {
        n++;
        if (n == 1) {
          return _json({
            'data': _order(
              payment: _va(),
              secondsLeft: 300,
              updatedAt: '2026-11-12T03:05:00Z',
            ),
          });
        }
        return _json({
          'data': _order(
            payment: _va(),
            secondsLeft: 900,
            updatedAt: '2026-11-12T03:01:00Z',
          ),
        });
      },
    );
    expect(find.text('00:05:00'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(n, greaterThanOrEqualTo(2));
    expect(find.text('00:15:00'), findsNothing);
    expect(find.text('00:05:00'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('online dengan payment_url tersimpan: Snap dibuka langsung', (
    tester,
  ) async {
    const url = 'https://app.sandbox.midtrans.com/snap/v4/lama';
    final withUrl = _order(
      method: 'online',
      payment: {
        'method': 'online',
        'status': 'pending',
        'amount': 99000,
        'payment_url': url,
      },
    );
    final h = await _open(
      tester,
      arg: withUrl,
      handler: (r) async => _json({'data': withUrl}),
    );
    await tester.tap(find.text('Bayar dengan QRIS / E-Wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.snapUrl, url);
    expect(h.reqs.where((r) => r.url.path.endsWith('/online')), isEmpty);
    await _close(tester);
  });

  testWidgets('VA yang sudah ada dipertahankan bila respons tanpa va', (
    tester,
  ) async {
    await _open(
      tester,
      arg: _order(payment: _va()),
      handler: (r) async =>
          _json({'data': _order(updatedAt: '2026-11-12T03:01:00Z')}),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('8808123456789'), findsOneWidget);
    await _close(tester);
  });

  testWidgets(
    'settlement terlambat pada pesanan expired: tanpa janji layanan',
    (tester) async {
      await _open(
        tester,
        arg: _order(payment: _va()),
        handler: (r) async => _json({
          'data': _order(
            status: 'expired',
            payStatus: 'paid',
            secondsLeft: 0,
            payment: _va(),
          ),
        }),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Pembayaran Diterima'), findsOneWidget);
      expect(
        find.textContaining('pesanan sudah kedaluwarsa. Hubungi penjual'),
        findsOneWidget,
      );
      expect(find.text('Kirim Rincian ke WhatsApp'), findsNothing);
      expect(find.text('Lihat Pesanan'), findsOneWidget);
      await _close(tester);
    },
  );

  testWidgets('409 pada createVa memicu refresh', (tester) async {
    final h = await _open(
      tester,
      arg: _order(),
      handler: (r) async {
        if (r.url.path.endsWith('/va')) {
          return _json({
            'error': {
              'code': 'CONFLICT',
              'message':
                  'Pesanan ini tidak menunggu pembayaran Virtual Account.',
            },
          }, 409);
        }
        return _json({'data': _order()});
      },
    );
    final before = h.reqs.where((r) => r.method == 'GET').length;
    await tester.tap(find.text('Buat Nomor Virtual Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('tidak menunggu pembayaran'), findsOneWidget);
    expect(h.reqs.where((r) => r.method == 'GET').length, before + 1);
    await _close(tester);
  });

  testWidgets('lembar sukses ditunda selama Snap terbuka', (tester) async {
    final gate = Completer<void>();
    var paid = false;
    await _open(
      tester,
      arg: _order(method: 'online'),
      opener: () => gate.future,
      handler: (r) async {
        if (r.url.path.endsWith('/online')) {
          return _json({
            'data': _order(
              method: 'online',
              payment: {
                'method': 'online',
                'status': 'pending',
                'amount': 99000,
                'payment_url': 'https://app.sandbox.midtrans.com/snap/v4/x',
              },
            ),
          });
        }
        return _json({
          'data': paid
              ? _order(
                  method: 'online',
                  status: 'confirmed',
                  payStatus: 'paid',
                  updatedAt: '2026-11-12T03:05:00Z',
                )
              : _order(method: 'online'),
        });
      },
    );
    await tester.tap(find.text('Bayar dengan QRIS / E-Wallet'));
    await tester.pump(const Duration(milliseconds: 100));
    paid = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Pembayaran Berhasil'), findsNothing);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Pembayaran Berhasil'), findsOneWidget);
    await _close(tester);
  });
}
