import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/promo_content_repository.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voucher_test.dart' show voucherJson;
import '../support/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

final _bannerPromo = {
  'id': 1, 'title': 'Diskon pembukaan', 'image_url': 'https://img.test/a.webp', 'target': 'promo',
  'promo': voucherJson(id: 7, extra: {'claimed': false}), 'merchant': null,
};
final _bannerToko = {
  'id': 2, 'title': 'Dapur Siti buka', 'image_url': 'https://img.test/b.webp', 'target': 'merchant', 'promo': null,
  'merchant': {'id': 3, 'slug': 'dapur-siti', 'business_name': 'Dapur Siti'},
};

Future<List<http.Request>> _pump(WidgetTester tester, List<Map<String, dynamic>> banners) async {
  final seen = <http.Request>[];
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      seen.add(req);
      final p = req.url.path;
      if (p.endsWith('/meta/categories')) return _json({'data': []});
      if (p.endsWith('/banners')) return _json({'data': banners});
      if (p.endsWith('/popup')) return _json({'data': null});
      if (p.endsWith('/claim')) return _json({'data': voucherJson(id: 7, extra: {'claimed': true})});
      return _json({'data': [], 'meta': {'total': 0}});
    }),
  );
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      Provider<PromoContentRepository>.value(value: PromoContentRepository(api)),
      Provider<VoucherRepository>.value(value: VoucherRepository(api)),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ...sessionProviders(api, auth: FakeAuth(loggedIn: true)),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
      onGenerateRoute: (s) => s.name == AppRoutes.storeProfile
          ? MaterialPageRoute(builder: (_) => Scaffold(body: Text('toko:${s.arguments}')))
          : null,
    ),
  ));
  await tester.pumpAndSettle();
  return seen;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('banner dari server tampil di carousel', (tester) async {
    await _pump(tester, [_bannerPromo, _bannerToko]);
    expect(find.text('Diskon pembukaan'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('tanpa banner server: area banner disembunyikan, tanpa kartu dummy', (tester) async {
    await _pump(tester, []);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Ambil di Titik Temu'), findsNothing);
  });

  testWidgets('ketuk banner voucher: lembar voucher → Klaim → POST + snackbar', (tester) async {
    final seen = await _pump(tester, [_bannerPromo]);
    await tester.tap(find.text('Diskon pembukaan'));
    await tester.pumpAndSettle();
    expect(find.text('Diskon 10% s.d. Rp 5.000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim'));
    await tester.pumpAndSettle();
    expect(seen.where((r) => r.method == 'POST' && r.url.path.endsWith('/me/vouchers/7/claim')), hasLength(1));
    expect(find.text('Voucher disimpan ke Voucher Saya'), findsOneWidget);
  });

  testWidgets('ketuk banner toko: buka halaman toko', (tester) async {
    await _pump(tester, [_bannerToko]);
    await tester.tap(find.text('Dapur Siti buka'));
    await tester.pumpAndSettle();
    expect(find.text('toko:dapur-siti'), findsOneWidget);
  });
}
