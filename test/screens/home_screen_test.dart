import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/screens/home/home_screen.dart';
import 'package:kateringkita_pbl/screens/home/search_screen.dart';
import 'package:kateringkita_pbl/widgets/food_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _card(int id, String name) => {
      'id': id,
      'name': name,
      'price': 5000,
      'merchant': {
        'id': 1,
        'slug': 'toko',
        'business_name': 'Toko',
        'is_open': true,
      },
    };

Object _menus(List<Map<String, dynamic>> items) => {
      'data': items,
      'meta': {'page': 1, 'limit': 20, 'total': items.length}
    };

const _cats = {
  'data': [
    {'id': 1, 'name': 'Danusan', 'slug': 'danusan', 'icon': ''},
    {'id': 2, 'name': 'Katering', 'slug': 'katering', 'icon': ''},
  ]
};

Widget _wrap(List<http.Request> log, Widget child,
    {Map<String, dynamic> menus = const {'data': [], 'meta': {'total': 0}},
    bool fail = false}) {
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      log.add(req);
      if (req.url.path.endsWith('/meta/categories')) return _json(_cats);
      if (fail) return _json({'error': {'message': 'Gagal'}}, 500);
      return _json(menus);
    }),
  );
  return Provider<CatalogRepository>.value(
    value: CatalogRepository(api),
    child: MaterialApp(home: child),
  );
}

void main() {
  _raceTest();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty menus shows empty text', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada menu yang tersedia saat ini.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two menus render two cards', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(
        log, const HomeScreen(),
        menus: Map<String, dynamic>.from(
            _menus([_card(1, 'A'), _card(2, 'B')]) as Map)));
    await tester.pumpAndSettle();
    expect(find.byType(FoodGridCard), findsNWidgets(2));
  });

  testWidgets('category chips from API and tap requests category',
      (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Katering'), findsOneWidget);
    await tester.tap(find.text('Katering'));
    await tester.pumpAndSettle();
    expect(
        log.any((r) =>
            r.url.path.endsWith('/menus') &&
            r.url.queryParameters['category'] == 'katering'),
        isTrue);
  });

  testWidgets('error shows retry button', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const HomeScreen(), fail: true));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('search debounces and queries q', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const SearchScreen(),
        menus: Map<String, dynamic>.from(
            _menus([_card(1, 'Lumpia')]) as Map)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lum');
    await tester.pump(const Duration(milliseconds: 200));
    expect(log.any((r) => r.url.queryParameters['q'] == 'lum'), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(log.any((r) => r.url.queryParameters['q'] == 'lum'), isTrue);
    expect(find.text('Lumpia'), findsOneWidget);
  });

  testWidgets('search empty result text', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const SearchScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Menu tidak ditemukan.'), findsOneWidget);
  });
}

void _raceTest() {
  testWidgets('stale category response is dropped', (tester) async {
    final api = ApiClient(
      baseUrl: 'https://x.test/api/v1',
      client: MockClient((req) async {
        if (req.url.path.endsWith('/meta/categories')) return _json(_cats);
        final cat = req.url.queryParameters['category'];
        if (cat == 'danusan') {
          await Future<void>.delayed(const Duration(seconds: 2));
          return _json(_menus([_card(1, 'ItemA')]));
        }
        if (cat == 'katering') return _json(_menus([_card(2, 'ItemB')]));
        return _json(_menus([]));
      }),
    );
    await tester.pumpWidget(Provider<CatalogRepository>.value(
      value: CatalogRepository(api),
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danusan'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Katering'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('ItemB'), findsOneWidget);
    expect(find.text('ItemA'), findsNothing);
  });
}
