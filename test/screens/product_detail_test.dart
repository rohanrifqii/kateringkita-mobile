import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/home/product_detail_screen.dart';
import 'package:kateringkita_pbl/screens/home/store_profile_screen.dart';
import 'package:kateringkita_pbl/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTheme extends ChangeNotifier implements ThemeProvider {
  @override
  bool get isDarkMode => false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _merchantJson({bool open = true}) => {
      'id': 1,
      'slug': 'dapur-a',
      'business_name': 'Dapur A',
      'is_open': open,
      'open_time': '08:00',
      'close_time': '17:00',
      'pickup_points': [
        {'id': 1, 'name': 'Gerbang Barat', 'description': 'Dekat parkir'}
      ],
    };

Map<String, dynamic> _menuJson({bool open = true, String badge = 'available'}) =>
    {
      'id': 7,
      'name': 'Nasi Box',
      'price': 20000,
      'badge': badge,
      'available': 10,
      'description': 'Enak sekali',
      'merchant': _merchantJson(open: open),
      'options': [
        {'id': 1, 'name': 'Pedas', 'extra_price': 2000},
        {'id': 2, 'name': 'Biasa', 'extra_price': 0},
      ],
    };

ProductModel _card({bool open = true, String badge = 'available'}) =>
    ProductModel.fromJson(_menuJson(open: open, badge: badge));

Widget _wrap(Widget screen, Object? args,
    {bool open = true, String badge = 'available'}) {
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/menus/7/reviews')) {
        return _json({
          'data': [
            {
              'rating': 5,
              'comment': 'Mantap rasanya',
              'customer_name': 'B*** S***',
              'created_at': '2026-01-02T03:04:05Z'
            }
          ]
        });
      }
      if (p.endsWith('/menus/7')) {
        return _json({'data': _menuJson(open: open, badge: badge)});
      }
      if (p.endsWith('/merchants/dapur-a')) {
        return _json({
          'data': {
            ..._merchantJson(open: open),
            'merchant_type': {'name': 'Danusan'},
            'rating_avg': 4.5,
            'rating_count': 12,
          }
        });
      }
      if (p.endsWith('/menus')) {
        return _json({
          'data': [_menuJson(open: open, badge: badge)],
          'meta': {'page': 1, 'limit': 20, 'total': 1}
        });
      }
      return _json({'error': {'message': 'x'}}, 404);
    }),
  );
  return MultiProvider(
    providers: [
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      ChangeNotifierProvider<ThemeProvider>.value(value: _FakeTheme()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                  settings: RouteSettings(arguments: args),
                  builder: (_) => screen),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('closed merchant shows notice and disables button',
      (tester) async {
    await _open(
        tester, _wrap(const ProductDetailScreen(), _card(open: false), open: false));
    expect(find.text('Toko sedang tutup'), findsWidgets);
    final btn = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('sold_out shows Habis and disables button', (tester) async {
    await _open(
        tester,
        _wrap(const ProductDetailScreen(), _card(badge: 'sold_out'),
            badge: 'sold_out'));
    expect(find.text('Habis'), findsWidgets);
    final btn = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('options show extra price, reviews shown', (tester) async {
    await _open(tester, _wrap(const ProductDetailScreen(), _card()));
    expect(find.textContaining('Pedas'), findsOneWidget);
    expect(find.textContaining('+ Rp 2.000'), findsOneWidget);
    expect(find.text('Biasa'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('B*** S***'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Mantap rasanya'), findsOneWidget);
    expect(find.text('Dapur A'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store profile loads from API by slug', (tester) async {
    await _open(tester, _wrap(const StoreProfileScreen(), 'dapur-a'));
    expect(find.text('Dapur A'), findsWidgets);
    expect(find.text('Nasi Box'.toUpperCase()), findsOneWidget);
    expect(find.text('Chat Dapur'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
