import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/voucher_repository.dart';
import 'package:kateringkita_pbl/screens/profile/my_vouchers_screen.dart';
import 'package:kateringkita_pbl/widgets/voucher_card.dart';
import 'package:provider/provider.dart';

import '../models/voucher_test.dart' show voucherJson;

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

final _lalu = DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String();
final _nanti = DateTime.now().toUtc().add(const Duration(days: 5)).toIso8601String();

Future<List<http.Request>> _pump(WidgetTester tester,
    {List<Map<String, dynamic>>? platform, List<Map<String, dynamic>>? mine}) async {
  final seen = <http.Request>[];
  var klaim = false;
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      seen.add(req);
      final p = req.url.path;
      if (p.endsWith('/claim')) {
        klaim = true;
        return _json({'data': voucherJson(id: 21, toko: false, extra: {'ends_at': _nanti})});
      }
      if (p.endsWith('/vouchers/platform')) {
        return _json({
          'data': platform ??
              [
                voucherJson(id: 21, type: 'fixed', value: 3000, toko: false, extra: {'claimed': klaim, 'ends_at': _nanti}),
                voucherJson(id: 22, toko: false, extra: {'claimed': true, 'ends_at': _nanti}),
              ],
        });
      }
      if (p.endsWith('/me/vouchers')) {
        return _json({
          'data': mine ??
              [
                voucherJson(id: 11, extra: {'usable': true, 'reason': null, 'ends_at': _nanti}),
                voucherJson(id: 22, toko: false, extra: {'usable': true, 'reason': null, 'ends_at': _nanti}),
                voucherJson(id: 12, type: 'fixed', value: 1000, extra: {'usable': false, 'reason': 'Voucher sudah berakhir.', 'ends_at': _lalu}),
              ],
        });
      }
      return _json({'error': {'code': 'NOT_FOUND', 'message': 'x'}}, 404);
    }),
  );
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(Provider<VoucherRepository>.value(
    value: VoucherRepository(api),
    child: const MaterialApp(home: MyVouchersScreen()),
  ));
  await tester.pumpAndSettle();
  return seen;
}

void main() {
  testWidgets('Voucher KateringKita (belum diklaim) + tab Bisa dipakai / Kedaluwarsa', (tester) async {
    await _pump(tester);
    expect(find.text('Voucher KateringKita'), findsOneWidget);
    final atas = find.byKey(const ValueKey('voucher-platform-list'));
    expect(find.descendant(of: atas, matching: find.byType(VoucherCard)), findsOneWidget);
    expect(find.descendant(of: atas, matching: find.text('Potongan Rp 3.000')), findsOneWidget);

    final saya = find.byKey(const ValueKey('voucher-saya-list'));
    expect(find.descendant(of: saya, matching: find.byType(VoucherCard)), findsNWidgets(2));
    await tester.tap(find.textContaining('Kedaluwarsa'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: saya, matching: find.byType(VoucherCard)), findsOneWidget);
    expect(find.text('Voucher sudah berakhir.'), findsOneWidget);
  });

  testWidgets('klaim voucher platform: POST, muat ulang, snackbar', (tester) async {
    final seen = await _pump(tester);
    final atas = find.byKey(const ValueKey('voucher-platform-list'));
    await tester.tap(find.descendant(of: atas, matching: find.widgetWithText(FilledButton, 'Klaim')));
    await tester.pumpAndSettle();
    expect(seen.where((r) => r.method == 'POST').single.url.path, '/api/v1/me/vouchers/21/claim');
    expect(seen.where((r) => r.url.path.endsWith('/me/vouchers')).length, 2);
    expect(find.text('Voucher disimpan ke Voucher Saya'), findsOneWidget);
    expect(find.descendant(of: atas, matching: find.byType(VoucherCard)), findsNothing);
  });

  testWidgets('kosong: ajakan klaim', (tester) async {
    await _pump(tester, platform: [], mine: []);
    expect(find.text('Belum ada voucher. Klaim dari halaman toko atau Voucher KateringKita.'), findsOneWidget);
  });
}
