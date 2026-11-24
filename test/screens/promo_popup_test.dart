import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/promo_content_repository.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/home/home_screen.dart';
import 'package:kateringkita_pbl/widgets/promo_popup.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voucher_test.dart' show voucherJson;
import '../support/session.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _popup({bool claimed = false, bool promo = true}) => {
      'id': 4,
      'title': 'Promo akhir pekan',
      'image_url': 'https://img.test/p.webp',
      'promo': promo ? voucherJson(id: 21, type: 'fixed', value: 3000, toko: false, extra: {'claimed': claimed}) : null,
    };

Future<List<http.Request>> _pump(WidgetTester tester, Map<String, dynamic>? popup) async {
  final seen = <http.Request>[];
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      seen.add(req);
      final p = req.url.path;
      if (p.endsWith('/meta/categories')) return _json({'data': []});
      if (p.endsWith('/banners')) return _json({'data': []});
      if (p.endsWith('/popup')) return _json({'data': popup});
      if (p.endsWith('/claim')) return _json({'data': voucherJson(id: 21, toko: false, extra: {'claimed': true})});
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
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pumpAndSettle();
  return seen;
}

void main() {
  testWidgets('tampil setelah beranda dimuat; ditutup → tidak tampil lagi hari yang sama', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, _popup());
    expect(find.byType(PromoPopupDialog), findsOneWidget);
    expect(find.text('Promo akhir pekan'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.byType(PromoPopupDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('popup_seen_4'), tanggalWib(DateTime.now()));

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, _popup());
    expect(find.byType(PromoPopupDialog), findsNothing);
  });

  testWidgets('sudah tampil kemarin → tampil lagi hari ini', (tester) async {
    SharedPreferences.setMockInitialValues({'popup_seen_4': '2000-01-01'});
    await _pump(tester, _popup());
    expect(find.byType(PromoPopupDialog), findsOneWidget);
  });

  testWidgets('voucher sudah diklaim → tidak tampil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, _popup(claimed: true));
    expect(find.byType(PromoPopupDialog), findsNothing);
  });

  testWidgets('Klaim voucher: POST, pop-up tertutup, snackbar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final seen = await _pump(tester, _popup());
    expect(find.text('Potongan Rp 3.000'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim voucher'));
    await tester.pumpAndSettle();
    expect(seen.where((r) => r.method == 'POST' && r.url.path.endsWith('/me/vouchers/21/claim')), hasLength(1));
    expect(find.byType(PromoPopupDialog), findsNothing);
    expect(find.text('Voucher disimpan ke Voucher Saya'), findsOneWidget);
  });

  testWidgets('tanpa voucher: hanya gambar + tutup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, _popup(promo: false));
    expect(find.byType(PromoPopupDialog), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Klaim voucher'), findsNothing);
  });
}
