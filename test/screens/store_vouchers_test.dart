import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/home/store_profile_screen.dart';
import 'package:kateringkita_pbl/widgets/voucher_card.dart';
import 'package:provider/provider.dart';

import '../models/voucher_test.dart' show voucherJson;
import '../support/session.dart';

class _FakeTheme extends ChangeNotifier implements ThemeProvider {
  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<List<http.Request>> _pump(WidgetTester tester,
    {bool login = true, http.Response? claimResponse}) async {
  final seen = <http.Request>[];
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      seen.add(req);
      final p = req.url.path;
      if (p.endsWith('/claim')) {
        return claimResponse ??
            _json({'data': voucherJson(id: 7, extra: {'claimed': true})});
      }
      if (p.endsWith('/merchants/dapur-a')) {
        return _json({
          'data': {
            'id': 3,
            'slug': 'dapur-a',
            'business_name': 'Dapur A',
            'is_open': true,
            'merchant_type': {'id': 1, 'name': 'Katering'},
            'open_time': '08:00',
            'close_time': '17:00',
            'rating_avg': 0,
            'rating_count': 0,
            'pickup_points': [],
            'vouchers': [
              voucherJson(id: 7, extra: {'claimed': false}),
              voucherJson(
                  id: 8,
                  type: 'fixed',
                  value: 2000,
                  extra: {'claimed': false, 'sold_out': true}),
            ],
          }
        });
      }
      if (p.endsWith('/menus')) {
        return _json({
          'data': [],
          'meta': {'page': 1, 'limit': 50, 'total': 0},
        });
      }
      return _json({
        'error': {'code': 'NOT_FOUND', 'message': 'x'}
      }, 404);
    }),
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      Provider<VoucherRepository>.value(value: VoucherRepository(api)),
      ChangeNotifierProvider<ThemeProvider>.value(value: _FakeTheme()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ...sessionProviders(api, auth: FakeAuth(loggedIn: login)),
    ],
    child: MaterialApp(
      home: const StoreProfileScreen(vendorName: 'dapur-a'),
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('layar-login')),
      },
    ),
  ));
  await tester.pumpAndSettle();
  return seen;
}

Iterable<http.Request> _claims(List<http.Request> seen) =>
    seen.where((r) => r.method == 'POST' && r.url.path.endsWith('/claim'));

void main() {
  testWidgets('voucher toko tampil: label, minimal belanja, Klaim / Habis',
      (tester) async {
    await _pump(tester);
    expect(find.text('Voucher toko'), findsOneWidget);
    expect(find.byType(VoucherCard), findsNWidgets(2));
    expect(find.text('Diskon 10% s.d. Rp 5.000'), findsOneWidget);
    expect(find.text('Min. belanja Rp 20.000'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Klaim'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Habis'))
            .onPressed,
        isNull);
  });

  testWidgets('klaim: POST lalu tombol jadi Diklaim + snackbar',
      (tester) async {
    final seen = await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim'));
    await tester.pumpAndSettle();
    expect(_claims(seen).single.url.path, '/api/v1/me/vouchers/7/claim');
    expect(find.text('Voucher disimpan ke Voucher Saya'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Diklaim'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Klaim'), findsNothing);
  });

  testWidgets('klaim ditolak server: pesan server di snackbar', (tester) async {
    await _pump(tester,
        claimResponse: _json({
          'error': {'code': 'CONFLICT', 'message': 'Kuota voucher sudah habis.'}
        }, 409));
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim'));
    await tester.pumpAndSettle();
    expect(find.text('Kuota voucher sudah habis.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Klaim'), findsOneWidget);
  });

  testWidgets('tamu: Klaim membuka login, tanpa permintaan klaim',
      (tester) async {
    final seen = await _pump(tester, login: false);
    await tester.tap(find.widgetWithText(FilledButton, 'Klaim'));
    await tester.pumpAndSettle();
    expect(find.text('layar-login'), findsOneWidget);
    expect(_claims(seen), isEmpty);
  });
}
