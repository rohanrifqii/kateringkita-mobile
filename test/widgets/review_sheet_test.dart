import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/widgets/review_sheet.dart';
import 'package:provider/provider.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _item(int id, String name) => {
      'menu_id': id,
      'menu_name': name,
      'qty': 1,
      'unit_price': 5000,
      'options': [],
      'line_total': 5000
    };

OrderApiModel _order() => OrderApiModel.fromJson({
      'code': 'KK-1',
      'status': 'completed',
      'payment_method': 'va',
      'payment_status': 'paid',
      'seconds_left': null,
      'pickup_point': {'id': 1, 'name': 'Gerbang', 'description': ''},
      'items': [_item(7, 'Nasi Box'), _item(8, 'Es Teh'), _item(7, 'Nasi Box')],
      'subtotal': 15000,
      'discount': 0,
      'service_fee': 0,
      'total': 15000,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62'},
      'can_cancel': false,
      'can_complete': false,
      'can_review': true,
    });

Future<Future<bool?> Function()> _open(
    WidgetTester t, Future<http.Response> Function(http.Request) h) async {
  final api =
      ApiClient(baseUrl: 'https://x.test/api/v1', client: MockClient(h));

  late BuildContext ctx;
  await t.pumpWidget(Provider<OrderRepository>.value(
    value: OrderRepository(api),
    child: MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ),
  ));
  return () {
    final f = showReviewSheet(ctx, _order());
    return f;
  };
}

void main() {
  testWidgets('kirim nonaktif tanpa bintang, satu baris per menu',
      (t) async {
    final open = await _open(t, (r) async => _json({}));
    open();
    await t.pumpAndSettle();
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);
    final btn = find.widgetWithText(ElevatedButton, 'Kirim Ulasan');
    expect(t.widget<ElevatedButton>(btn).onPressed, isNull);
    await t.tap(find.byKey(const Key('star-7-4')));
    await t.pump();
    expect(t.widget<ElevatedButton>(btn).onPressed, isNotNull);
  });

  testWidgets('409 sudah diulas tampil pada baris menu', (t) async {
    final open = await _open(
        t,
        (r) async => _json({
              'error': {
                'code': 'CONFLICT',
                'message': 'Konflik',
                'fields': {
                  'items.1.menu_id': ['Menu ini sudah diulas.']
                }
              }
            }, 409));
    open();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('star-7-5')));
    await t.tap(find.byKey(const Key('star-8-3')));
    await t.pump();
    await t.tap(find.text('Kirim Ulasan'));
    await t.pumpAndSettle();
    expect(find.text('Menu ini sudah diulas.'), findsOneWidget);
    expect(find.text('Kirim Ulasan'), findsOneWidget);
  });

  testWidgets('sukses menutup sheet dengan true, hanya baris berbintang dikirim',
      (t) async {
    Map? sent;
    final open = await _open(t, (r) async {
      sent = jsonDecode(r.body) as Map;
      return _json({
        'data': {
          'order_code': 'KK-1',
          'reviewed_menu_ids': [8]
        }
      }, 201);
    });
    final res = open();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('star-8-3')));
    await t.pump();
    await t.tap(find.text('Kirim Ulasan'));
    await t.pumpAndSettle();
    expect(await res, true);
    expect((sent!['items'] as List).length, 1);
    expect((sent!['items'] as List).first['menu_id'], 8);
    expect(find.text('Kirim Ulasan'), findsNothing);
  });
}
