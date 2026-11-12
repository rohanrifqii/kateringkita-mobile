import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/home/store_profile_screen.dart';
import 'package:provider/provider.dart';

class _FakeTheme extends ChangeNotifier implements ThemeProvider {
  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const _merchant = {
  'id': 1,
  'slug': 'dapur-a',
  'business_name': 'Dapur A',
  'is_open': true,
};

Map<String, dynamic> _card(int id, String name, int ratingCount) => {
      'id': id,
      'name': name,
      'price': 10000,
      'merchant': _merchant,
      'available': 20,
      'rating_avg': ratingCount > 0 ? 4.5 : 0,
      'rating_count': ratingCount,
    };

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

Future<List<Uri>> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? menus,
  Future<http.Response> Function(int menuId, int call)? reviews,
}) async {
  final seen = <Uri>[];
  var calls = 0;
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      seen.add(req.url);
      final p = req.url.path;
      final m = RegExp(r'/menus/(\d+)/reviews$').firstMatch(p);
      if (m != null) {
        calls++;
        final id = int.parse(m.group(1)!);
        if (reviews != null) return reviews(id, calls);
        return _json({
          'data': id == 7
              ? [
                  {
                    'rating': 5,
                    'comment': 'Nasinya pulen',
                    'customer_name': 'Bu***',
                    'created_at': _ago(const Duration(hours: 2)),
                  },
                  {
                    'rating': 3,
                    'comment': null,
                    'customer_name': 'An***',
                    'created_at': _ago(const Duration(days: 3)),
                  },
                ]
              : [
                  {
                    'rating': 4,
                    'comment': 'Segar',
                    'customer_name': 'Ci***',
                    'created_at': _ago(const Duration(minutes: 10)),
                  },
                ],
          'meta': {'page': 1, 'limit': 5, 'total': 2},
        });
      }
      if (p.endsWith('/merchants/dapur-a')) {
        return _json({
          'data': {
            ..._merchant,
            'merchant_type': {'id': 1, 'name': 'Katering'},
            'open_time': '08:00',
            'close_time': '17:00',
            'rating_avg': 4.4,
            'rating_count': 12,
            'pickup_points': [],
          }
        });
      }
      if (p.endsWith('/menus')) {
        return _json({
          'data': menus ??
              [
                _card(7, 'Nasi Box', 8),
                _card(8, 'Es Teh', 4),
                _card(9, 'Kerupuk', 0),
              ],
          'meta': {'page': 1, 'limit': 50, 'total': 3},
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
      ChangeNotifierProvider<ThemeProvider>.value(value: _FakeTheme()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
    ],
    child: const MaterialApp(home: StoreProfileScreen(vendorName: 'dapur-a')),
  ));
  await tester.pumpAndSettle();
  return seen;
}

Iterable<Uri> _reviewCalls(List<Uri> seen) =>
    seen.where((u) => u.path.endsWith('/reviews'));

void main() {
  testWidgets('ketuk rating: tab Penilaian, ringkasan toko + ulasan terbaru',
      (tester) async {
    final seen = await _pump(tester);
    expect(_reviewCalls(seen), isEmpty);

    await tester.tap(find.byKey(const ValueKey('store-rating')));
    await tester.pumpAndSettle();

    // Hanya menu berulasan; 5 ulasan per menu.
    final calls = _reviewCalls(seen).toList();
    expect(calls.map((u) => u.path.split('/')[4]).toSet(), {'7', '8'});
    expect(calls.every((u) => u.queryParameters['limit'] == '5'), isTrue);

    expect(
        tester.widget<Text>(find.byKey(const ValueKey('store-rating-avg'))).data,
        '4.4');
    expect(find.text('Dari 12 penilaian'), findsOneWidget);

    // Urut terbaru: Ci (10 menit), Bu (2 jam), An (3 hari).
    final names = tester
        .widgetList<Text>(find.textContaining('***'))
        .map((t) => t.data)
        .toList();
    expect(names, ['Ci***', 'Bu***', 'An***']);
    expect(find.text('Menu: Es Teh'), findsOneWidget);
    expect(find.text('Menu: Nasi Box'), findsNWidgets(2));
    expect(find.text('Nasinya pulen'), findsOneWidget);
  });

  testWidgets('tab Penilaian lewat tab bar; kosong tanpa request',
      (tester) async {
    final seen = await _pump(tester, menus: [_card(9, 'Kerupuk', 0)]);
    await tester.tap(find.text('Penilaian'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada ulasan untuk menu toko ini.'), findsOneWidget);
    expect(_reviewCalls(seen), isEmpty);
  });

  testWidgets('galat: pesan + Coba Lagi memuat ulang', (tester) async {
    final seen = await _pump(tester, reviews: (id, call) async {
      if (call <= 2) {
        return _json({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Server sibuk.'}
        }, 500);
      }
      return _json({
        'data': [
          {
            'rating': 5,
            'comment': 'Enak',
            'customer_name': 'Di***',
            'created_at': _ago(const Duration(hours: 1)),
          }
        ]
      });
    });
    await tester.tap(find.text('Penilaian'));
    await tester.pumpAndSettle();
    expect(find.text('Server sibuk.'), findsOneWidget);

    await tester.ensureVisible(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Server sibuk.'), findsNothing);
    expect(find.text('Di***'), findsNWidgets(2));
    expect(_reviewCalls(seen), hasLength(4));
  });
}
