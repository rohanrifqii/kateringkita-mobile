import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/cart_store.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/orders/checkout_screen.dart';
import 'package:kateringkita_pbl/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/quiet_map.dart';
import '../models/voucher_test.dart' show voucherJson;

/// testWidgets tanpa derau pemberitahuan tile OSM dari flutter_map.
void _testWidgets(String description, WidgetTesterCallback body) =>
    testWidgets(description, (t) => withoutOsmTileNotice(() => body(t)));

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  /// Sesi palsu tidak pernah dimuat dari server: selalu siap.
  @override
  Future<void> get ready async {}

  _FakeAuth(this._u);
  final ApiUser? _u;

  @override
  ApiUser? get user => _u;

  @override
  bool get isLoggedIn => _u != null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _budi = ApiUser(
  id: 1,
  role: 'customer',
  fullName: 'Budi',
  phone: '0812345678901',
  favoritePickupPointId: 2,
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _merchant() => {
      'id': 1,
      'slug': 'dapur-a',
      'business_name': 'Dapur A',
      'is_open': true,
      'open_time': '08:00',
      'close_time': '17:00',
      'pickup_points': [
        {'id': 1, 'name': 'Gerbang Barat', 'description': 'Dekat parkir'},
        {'id': 2, 'name': 'Perpustakaan Pusat'},
      ],
    };

Map<String, dynamic> _menu(int id, String name, int price,
        {int preorderDays = 0}) =>
    {
      'id': id,
      'name': name,
      'price': price,
      'available': 10,
      'merchant': _merchant(),
      'options': [],
      'is_preorder': preorderDays > 0,
      'preorder_days': preorderDays,
      'badge': preorderDays > 0 ? 'preorder' : 'available',
    };

ProductModel _p(int id, String name, int price, {int preorderDays = 0}) =>
    ProductModel.fromJson(_menu(id, name, price, preorderDays: preorderDays));

Map<String, dynamic> _quote(int n) => {
      'items': [
        for (var i = 0; i < n; i++)
          {
            'menu_id': 7 + i,
            'menu_name': 'X$i',
            'qty': 1,
            'unit_price': 45000,
            'options': [],
            'line_total': 45000,
            'available': true,
          }
      ],
      'subtotal': 90000,
      'discount': 0,
      'service_fee': 9000,
      'total': 99000,
      'warnings': [
        {
          'code': 'LOW_STOCK',
          'menu_id': 7,
          'available': 2,
          'message': 'Stok Nasi Box tinggal 2.'
        }
      ],
    };

Map<String, dynamic> _order() => {
      'code': 'KK-1',
      'status': 'holding',
      'payment_method': 'online',
      'payment_status': 'unpaid',
      'pickup_point': {'id': 2, 'name': 'Perpustakaan Pusat'},
      'items': [],
      'subtotal': 90000,
      'discount': 0,
      'service_fee': 9000,
      'total': 99000,
      'created_at': '2026-11-12T03:00:00Z',
      'updated_at': '2026-11-12T03:00:00Z',
      'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62812'},
    };

class _PaymentProbe extends StatelessWidget {
  const _PaymentProbe();

  @override
  Widget build(BuildContext context) {
    final o = ModalRoute.of(context)!.settings.arguments as OrderApiModel;
    return Scaffold(body: Text('PAY ${o.code} ${o.total}'));
  }
}

class _Harness {
  final requests = <http.Request>[];
  late final CartProvider cart;

  List<http.Request> get quotes =>
      requests.where((r) => r.url.path.endsWith('/orders/quote')).toList();
  List<http.Request> get orders =>
      requests.where((r) => r.url.path.endsWith('/orders')).toList();
}

Future<_Harness> _open(
  WidgetTester tester, {
  required List<(ProductModel, int)> lines,
  ApiUser? user = _budi,
  Future<http.Response> Function(int n)? onOrder,
  Future<http.Response> Function(int n)? onQuote,
  Future<http.Response> Function(int n)? onMenu,
  List<Map<String, dynamic>> mine = const [],
  List<Map<String, dynamic>> platform = const [],
  Future<http.Response> Function(http.Request req)? onQuoteReq,
}) async {
  final h = _Harness();
  // Keranjang memakai penyimpanan perangkat (di memori) seperti di aplikasi.
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  h.cart = CartProvider(store: CartStore(SharedPreferencesAsync()));
  for (final (p, q) in lines) {
    h.cart.add(p, qty: q);
  }
  var orderCalls = 0;
  var quoteCalls = 0;
  var menuCalls = 0;
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    timeout: const Duration(seconds: 2),
    client: MockClient((req) async {
      h.requests.add(req);
      final p = req.url.path;
      if (p.endsWith('/orders/quote')) {
        quoteCalls++;
        if (onQuoteReq != null) return onQuoteReq(req);
        if (onQuote != null) return onQuote(quoteCalls);
        final n = (jsonDecode(req.body)['items'] as List).length;
        return _json({'data': _quote(n)});
      }
      if (p.endsWith('/claim')) {
        final id = int.parse(p.split('/')[5]); // /api/v1/me/vouchers/:id/claim
        return _json({'data': {...platform.firstWhere((v) => v['id'] == id), 'claimed': true}});
      }
      if (p.endsWith('/me/vouchers')) return _json({'data': mine});
      if (p.endsWith('/vouchers/platform')) return _json({'data': platform});
      if (p.endsWith('/orders')) {
        orderCalls++;
        if (onOrder != null) return onOrder(orderCalls);
        return _json({'data': _order()}, 201);
      }
      final m = RegExp(r'/menus/(\d+)$').firstMatch(p);
      if (m != null) {
        menuCalls++;
        if (onMenu != null) return onMenu(menuCalls);
        final id = int.parse(m.group(1)!);
        final line = lines.firstWhere((l) => l.$1.id == id).$1;
        return _json({
          'data': _menu(id, line.name, line.price,
              preorderDays: line.preorderDays)
        });
      }
      return _json({
        'error': {'code': 'NOT_FOUND', 'message': 'x'}
      }, 404);
    }),
  );

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      Provider<VoucherRepository>.value(value: VoucherRepository(api)),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(user)),
      ChangeNotifierProvider<CartProvider>.value(value: h.cart),
    ],
    child: MaterialApp(
      routes: {
        AppRoutes.paymentFor('KK-1'): (_) => const _PaymentProbe(),
        AppRoutes.login: (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('batal-login'),
              ),
            ),
      },
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(c,
                MaterialPageRoute(builder: (_) => const CheckoutScreen())),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  // Debounce quote 400 ms.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _pay(WidgetTester tester) async {
  await tester.tap(find.text('Proses Pembayaran'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ya, Bayar Sekarang'));
  await tester.pump();
}

void main() {
  voucherTests();
  _testWidgets('two-line cart: quote called, server total shown',
      (tester) async {
    final h = await _open(tester, lines: [
      (_p(7, 'Nasi Box', 20000), 1),
      (_p(8, 'Es Teh', 5000), 2),
    ]);
    expect(h.quotes, isNotEmpty);
    final body = jsonDecode(h.quotes.last.body) as Map<String, dynamic>;
    expect((body['items'] as List).length, 2);
    expect(body['items'][1], {'menu_id': 8, 'qty': 2, 'option_ids': []});
    // Bawaan = titik favorit user (id 2) karena dilayani toko.
    expect(body['pickup_point_id'], 2);
    expect(body.containsKey('pickup_at'), isFalse);
    expect(find.text('Perpustakaan Pusat'), findsWidgets);
    expect(find.text('Rp 99.000'), findsWidgets);
    expect(find.text('Rp 9.000'), findsOneWidget);
    // Estimasi lokal (20.000 + 2×5.000) tidak dipakai sebagai total.
    expect(find.text('Rp 30.000'), findsNothing);
    expect(find.text('Stok Nasi Box tinggal 2.'), findsOneWidget);
    // Nama & HP terisi dari user.
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('0812345678901'), findsOneWidget);
    final btn = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(btn.onPressed, isNotNull);
  });

  _testWidgets('titik temu favorit tidak dilayani toko: pakai titik pertama',
      (tester) async {
    final h = await _open(tester,
        lines: [(_p(7, 'Nasi Box', 20000), 1)],
        user: const ApiUser(
          id: 1,
          role: 'customer',
          fullName: 'Budi',
          phone: '0812345678901',
          favoritePickupPointId: 9,
        ));
    final body = jsonDecode(h.quotes.last.body) as Map<String, dynamic>;
    expect(body['pickup_point_id'], 1);
    expect(find.text('Gerbang Barat'), findsWidgets);
  });

  _testWidgets('pre-order: Secepatnya disabled, pay disabled until date picked',
      (tester) async {
    final h = await _open(tester, lines: [
      (_p(9, 'Tumpeng', 150000, preorderDays: 1), 1),
    ]);
    final asap =
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Secepatnya'));
    expect(asap.onSelected, isNull);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);

    await tester.ensureVisible(find.text('Pilih Tanggal & Jam'));
    await tester.tap(find.text('Pilih Tanggal & Jam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final body = jsonDecode(h.quotes.last.body) as Map<String, dynamic>;
    final at = DateTime.parse(body['pickup_at'] as String);
    expect((body['pickup_at'] as String).endsWith('Z'), isTrue);
    final now = DateTime.now().toUtc();
    expect(!at.isBefore(DateTime.utc(now.year, now.month, now.day)), isTrue);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
  });

  _testWidgets('no cash option, only QRIS/E-Wallet and Virtual Account',
      (tester) async {
    await _open(tester, lines: [(_p(7, 'Nasi Box', 20000), 1)]);
    expect(find.text('QRIS / E-Wallet'), findsOneWidget);
    expect(find.text('Virtual Account'), findsOneWidget);
    expect(find.textContaining('Tunai'), findsNothing);
    expect(find.textContaining('COD'), findsNothing);
  });

  _testWidgets('timeout then retry reuses the same Idempotency-Key',
      (tester) async {
    final h = await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onOrder: (n) => n == 1
          ? Completer<http.Response>().future
          : Future.value(_json({'data': _order()}, 201)),
    );
    await _pay(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Koneksi lambat. Coba lagi. Cek tab Pesanan sebelum mencoba lagi.'),
        findsOneWidget);
    expect(h.cart.items, isNotEmpty);
    expect(await SharedPreferencesAsync().getString(CartStore.storageKey),
        isNotNull);

    await _pay(tester);
    await tester.pumpAndSettle();

    expect(h.orders.length, 2);
    final k1 = h.orders[0].headers['Idempotency-Key'];
    final k2 = h.orders[1].headers['Idempotency-Key'];
    expect(k1, isNotNull);
    expect(k1, isNotEmpty);
    expect(k2, k1);
    final body = jsonDecode(h.orders[1].body) as Map<String, dynamic>;
    expect(body['payment_method'], 'online');
    expect(body['customer_name'], 'Budi');
    expect(body['note'], isNull);
    expect(find.text('PAY KK-1 99000'), findsOneWidget);
    expect(h.cart.items, isEmpty);
    // Pesanan berhasil: keranjang tersimpan ikut dihapus dari perangkat.
    expect(await SharedPreferencesAsync().getString(CartStore.storageKey),
        isNull);
  });

  _testWidgets('409 OUT_OF_STOCK shows field message on the first row, VA sent',
      (tester) async {
    final h = await _open(
      tester,
      lines: [
        (_p(7, 'Nasi Box', 20000), 3),
        (_p(8, 'Es Teh', 5000), 1),
      ],
      onOrder: (_) async => _json({
        'error': {
          'code': 'OUT_OF_STOCK',
          'message': 'Stok tidak cukup.',
          'fields': {
            'items.0.qty': ['Sisa 1 porsi.']
          }
        }
      }, 409),
    );
    await tester.ensureVisible(find.text('Virtual Account'));
    await tester.tap(find.text('Virtual Account'));
    await tester.pump();
    final quotesBefore = h.quotes.length;
    await _pay(tester);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Total/status bayar disegarkan dari server setelah gagal.
    expect(h.quotes.length, quotesBefore + 1);
    expect(jsonDecode(h.orders.single.body)['payment_method'], 'va');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('cart-line-7:0')),
            matching: find.text('Sisa 1 porsi.')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('cart-line-8:0')),
            matching: find.text('Sisa 1 porsi.')),
        findsNothing);
    expect(find.text('Stok tidak cukup.'), findsOneWidget);
  });

  _testWidgets('picking another pickup point re-quotes with its id',
      (tester) async {
    final h = await _open(tester, lines: [(_p(7, 'Nasi Box', 20000), 1)]);
    final before = h.quotes.length;
    await tester.ensureVisible(find.text('Buka Peta'));
    await tester.tap(find.text('Buka Peta'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Titik Temu'), findsOneWidget);
    await tester.tap(find.text('Gerbang Barat'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(h.quotes.length, before + 1);
    expect(jsonDecode(h.quotes.last.body)['pickup_point_id'], 1);
    expect(find.text('Gerbang Barat'), findsWidgets);
    expect(find.text('Dekat parkir'), findsOneWidget);
  });

  _testWidgets('guest cancelling login leaves checkout', (tester) async {
    await _open(tester,
        lines: [(_p(7, 'Nasi Box', 20000), 1)], user: null);
    expect(find.text('batal-login'), findsOneWidget);
    await tester.tap(find.text('batal-login'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });

  _testWidgets('empty cart shows empty state', (tester) async {
    await _open(tester, lines: []);
    expect(find.text('Keranjang masih kosong'), findsOneWidget);
    expect(find.text('Cari Menu'), findsOneWidget);
  });

  _testWidgets('timeout, keluar lalu masuk checkout lagi: kunci yang sama',
      (tester) async {
    final h = await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onOrder: (n) => n == 1
          ? Completer<http.Response>().future
          : Future.value(_json({'data': _order()}, 201)),
    );
    await _pay(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cek tab Pesanan sebelum mencoba lagi.'),
        findsOneWidget);

    // Keluar dari checkout, lalu masuk lagi.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsNothing);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await _pay(tester);
    await tester.pumpAndSettle();
    expect(h.orders.length, 2);
    final k1 = h.orders[0].headers['Idempotency-Key'];
    expect(k1, isNotEmpty);
    expect(h.orders[1].headers['Idempotency-Key'], k1);
    expect(find.text('PAY KK-1 99000'), findsOneWidget);
  });

  _testWidgets('galat parse setelah 201: tombol pulih, kunci dipakai ulang',
      (tester) async {
    final h = await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onOrder: (n) async => n == 1
          ? http.Response('<html>rusak</html>', 201)
          : _json({'data': _order()}, 201),
    );
    await _pay(tester);
    await tester.pumpAndSettle();
    expect(find.text('Terjadi kesalahan. Coba lagi.'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
    expect(h.cart.items, isNotEmpty);

    await _pay(tester);
    await tester.pumpAndSettle();
    expect(h.orders.length, 2);
    expect(h.orders[1].headers['Idempotency-Key'],
        h.orders[0].headers['Idempotency-Key']);
    expect(find.text('PAY KK-1 99000'), findsOneWidget);
  });

  _testWidgets('galat tak terduga saat quote: pesan, tanpa spinner',
      (tester) async {
    await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onQuote: (_) async => _json({'data': 'rusak'}),
    );
    expect(find.text('Terjadi kesalahan. Coba lagi.'), findsOneWidget);
    expect(find.text('Menghitung total…'), findsNothing);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
  });

  _testWidgets('galat tak terduga saat memuat titik temu: bisa coba lagi',
      (tester) async {
    await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onMenu: (_) async => _json({'data': 'rusak'}),
    );
    expect(find.text('Gagal memuat titik temu'), findsOneWidget);
    expect(find.textContaining('Terjadi kesalahan. Coba lagi.'), findsWidgets);
    expect(find.text('Memuat titik temu…'), findsNothing);
  });

  _testWidgets('galat kolom pemesan tampil di bawah kolomnya', (tester) async {
    await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onOrder: (_) async => _json({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Data tidak valid.',
          'fields': {
            'customer_name': ['Nama wajib diisi.'],
            'customer_phone': ['Nomor WhatsApp tidak valid.'],
            'note': ['Catatan terlalu panjang.'],
          }
        }
      }, 422),
    );
    await _pay(tester);
    await tester.pumpAndSettle();

    Finder under(String label, String msg) => find.descendant(
        of: find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_OrderField')),
        matching: find.text(msg));
    expect(under('Nama Lengkap', 'Nama wajib diisi.'), findsOneWidget);
    expect(under('Kontak Penerima', 'Nomor WhatsApp tidak valid.'),
        findsOneWidget);
    expect(under('Catatan Khusus', 'Catatan terlalu panjang.'), findsOneWidget);
    expect(under('Nama Lengkap', 'Nomor WhatsApp tidak valid.'), findsNothing);
  });

  _testWidgets('409 MERCHANT_CLOSED memicu quote ulang', (tester) async {
    final h = await _open(
      tester,
      lines: [(_p(7, 'Nasi Box', 20000), 1)],
      onOrder: (_) async => _json({
        'error': {'code': 'MERCHANT_CLOSED', 'message': 'Toko sedang tutup.'}
      }, 409),
    );
    final before = h.quotes.length;
    await _pay(tester);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(h.quotes.length, before + 1);
    expect(find.text('Toko sedang tutup.'), findsOneWidget);
  });
}

// ---------------- Voucher (dua slot: toko + platform) ----------------
Future<http.Response> _quoteVoucher(http.Request req) async {
  final kode = (jsonDecode(req.body)['promo_codes'] as List?)?.cast<String>() ?? const [];
  final q = _quote(1);
  if (kode.contains('GAGAL')) {
    return _json({
      'error': {
        'code': 'PROMO_INVALID',
        'message': 'Kuota promo sudah habis.',
        'fields': {'promo_codes': ['Kuota promo sudah habis.'], 'promo_code': ['Kuota promo sudah habis.']},
      }
    }, 422);
  }
  return _json({
    'data': {
      ...q,
      'merchant_discount': kode.contains('TOKO10') ? 4500 : 0,
      'platform_discount': kode.contains('HEMAT3K') ? 3000 : 0,
      'discount': (kode.contains('TOKO10') ? 4500 : 0) + (kode.contains('HEMAT3K') ? 3000 : 0),
      'vouchers_applied': [
        if (kode.contains('TOKO10')) {'id': 11, 'code': 'TOKO10', 'slot': 'toko', 'amount': 4500},
        if (kode.contains('HEMAT3K')) {'id': 21, 'code': 'HEMAT3K', 'slot': 'platform', 'amount': 3000},
      ],
    }
  });
}

List<String> _lastCodes(_Harness h) =>
    ((jsonDecode(h.quotes.last.body)['promo_codes'] as List?) ?? const []).cast<String>();

void voucherTests() {
  final mine = [
    {...voucherJson(id: 11), 'code': 'TOKO10', 'usable': true, 'reason': null},
    {...voucherJson(id: 12, type: 'fixed', value: 2000), 'code': 'MINBESAR', 'usable': false, 'reason': 'Minimal belanja Rp 100.000'},
  ];
  final platform = [
    {...voucherJson(id: 21, type: 'fixed', value: 3000, toko: false), 'code': 'HEMAT3K', 'claimed': false},
  ];

  _testWidgets('voucher: pilih voucher toko + klaim & pakai voucher platform → promo_codes 2 kode, ringkasan per slot',
      (tester) async {
    final h = await _open(tester,
        lines: [(_p(7, 'Nasi Box', 45000), 2)],
        mine: mine,
        platform: platform,
        onQuoteReq: _quoteVoucher);
    expect(find.text('Voucher toko'), findsOneWidget);
    expect(find.text('Voucher platform'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('voucher-slot-toko')));
    await tester.pumpAndSettle();
    final q = h.requests.lastWhere((r) => r.url.path.endsWith('/me/vouchers')).url.queryParameters;
    expect(q, {'merchant_id': '1', 'subtotal': '90000', 'payment_method': 'online'});
    // yang tidak memenuhi syarat tampil dengan alasan & tidak bisa dipilih
    expect(find.text('Minimal belanja Rp 100.000'), findsOneWidget);
    final pakai = find.widgetWithText(FilledButton, 'Pakai');
    expect(tester.widgetList<FilledButton>(pakai).where((b) => b.onPressed == null).length, 1);
    await tester.tap(pakai.first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_lastCodes(h), ['TOKO10']);

    await tester.tap(find.byKey(const ValueKey('voucher-slot-platform')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim & pakai'));
    await tester.pumpAndSettle(); // klaim async selesai, lembar tertutup
    await tester.pump(const Duration(milliseconds: 500)); // debounce quote
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r.url.path.endsWith('/me/vouchers/21/claim')), hasLength(1));
    expect(_lastCodes(h), ['TOKO10', 'HEMAT3K']);
    expect(find.text('- Rp 4.500'), findsOneWidget);
    expect(find.text('- Rp 3.000'), findsOneWidget);
  });

  _testWidgets('quote gagal: pemilih voucher memakai subtotal keranjang, bukan 0', (tester) async {
    final h = await _open(tester,
        lines: [(_p(7, 'Nasi Box', 45000), 2)],
        mine: mine,
        onQuote: (_) async => _json({
              'error': {'code': 'VALIDATION_ERROR', 'message': 'Promo tidak bisa dipakai.'}
            }, 422));
    await tester.tap(find.byKey(const ValueKey('voucher-slot-toko')));
    await tester.pumpAndSettle();
    final q = h.requests.lastWhere((r) => r.url.path.endsWith('/me/vouchers')).url.queryParameters;
    expect(q['subtotal'], '90000');
  });

  _testWidgets('galat voucher dari server tampil di bagian voucher; Pakai kode manual tetap ada', (tester) async {
    final h = await _open(tester,
        lines: [(_p(7, 'Nasi Box', 45000), 2)],
        onQuoteReq: _quoteVoucher);
    await tester.tap(find.text('Pakai kode'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('voucher-manual')), 'gagal');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_lastCodes(h), ['GAGAL']);
    expect(find.text('Kuota promo sudah habis.'), findsOneWidget);
  });
}
