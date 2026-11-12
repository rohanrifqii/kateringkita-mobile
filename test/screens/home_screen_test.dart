import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/home/home_screen.dart';
import 'package:kateringkita_pbl/screens/home/search_screen.dart';
import 'package:kateringkita_pbl/widgets/food_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/session.dart';

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
    bool fail = false,
    FakeAuth? auth,
    Map<String, WidgetBuilder> routes = const {}}) {
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    client: MockClient((req) async {
      log.add(req);
      if (req.url.path.endsWith('/meta/categories')) return _json(_cats);
      if (fail) return _json({'error': {'message': 'Gagal'}}, 500);
      return _json(menus);
    }),
  );
  return MultiProvider(
    providers: [
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ...sessionProviders(api, auth: auth),
    ],
    child: MaterialApp(home: child, routes: routes),
  );
}

void main() {
  _raceTest();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('banner info layanan', () {
    final stubRoutes = <String, WidgetBuilder>{
      AppRoutes.search: (_) => const Scaffold(body: Text('layar-cari')),
      AppRoutes.orders: (_) => const Scaffold(body: Text('layar-pesanan')),
      AppRoutes.aiAssistant: (_) => const Scaffold(body: Text('layar-ai')),
    };

    Future<void> nextBanner(WidgetTester tester) async {
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('tanpa janji diskon/ongkir; CTA ke tab yang ada',
        (tester) async {
      final tabs = <int>[];
      await tester.pumpWidget(_wrap(
          <http.Request>[], HomeScreen(onTabChange: tabs.add),
          routes: stubRoutes));
      await tester.pumpAndSettle();

      for (final fake in [
        'Summer Sale',
        'GRATIS ONGKIR',
        'Antar Seluruh UB',
        'Klaim Promo →',
      ]) {
        expect(find.text(fake), findsNothing);
      }
      expect(find.textContaining(RegExp('diskon|ongkir', caseSensitive: false)),
          findsNothing);

      expect(find.text('Ambil di Titik Temu'), findsOneWidget);
      await nextBanner(tester);
      expect(find.text('VA, QRIS & E-Wallet'), findsOneWidget);
      await tester.tap(find.text('Lihat Pesanan →'));
      await tester.pumpAndSettle();
      await nextBanner(tester);
      expect(find.text('Atur Waktu Ambil'), findsOneWidget);
      await tester.tap(find.text('Tanya AI →'));
      await tester.pumpAndSettle();
      expect(tabs, [1, 2]);
    });

    testWidgets('Cari Menu membuka layar Cari', (tester) async {
      await tester.pumpWidget(
          _wrap(<http.Request>[], const HomeScreen(), routes: stubRoutes));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cari Menu →'));
      await tester.pumpAndSettle();
      expect(find.text('layar-cari'), findsOneWidget);
    });

    testWidgets('Home tanpa tab: CTA Pesanan membuka rute Pesanan',
        (tester) async {
      await tester.pumpWidget(
          _wrap(<http.Request>[], const HomeScreen(), routes: stubRoutes));
      await tester.pumpAndSettle();
      await nextBanner(tester);
      await tester.tap(find.text('Lihat Pesanan →'));
      await tester.pumpAndSettle();
      expect(find.text('layar-pesanan'), findsOneWidget);
    });
  });

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

  testWidgets('kartu: hati dari is_favorite hanya untuk pembeli',
      (tester) async {
    final menus = Map<String, dynamic>.from(_menus([
      {..._card(1, 'A'), 'is_favorite': true},
      _card(2, 'B'),
    ]) as Map);
    final auth = FakeAuth(loggedIn: true);
    await tester.pumpWidget(
        _wrap(<http.Request>[], const HomeScreen(), menus: menus, auth: auth));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    // Keluar: kartu lama tidak boleh memperlihatkan favorit akun tadi.
    auth.set(false);
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('kartu: ketuk hati -> PUT /me/favorites/:id', (tester) async {
    final log = <http.Request>[];
    await tester.pumpWidget(_wrap(log, const HomeScreen(),
        menus: Map<String, dynamic>.from(_menus([_card(5, 'A')]) as Map),
        auth: FakeAuth(loggedIn: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    final put = log.where((r) => r.method == 'PUT').single;
    expect(put.url.path, '/api/v1/me/favorites/5');
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('masuk/keluar memuat ulang menu (is_favorite per sesi)',
      (tester) async {
    final log = <http.Request>[];
    final auth = FakeAuth();
    await tester.pumpWidget(_wrap(log, const HomeScreen(), auth: auth));
    await tester.pumpAndSettle();
    int menuCalls() => log.where((r) => r.url.path.endsWith('/menus')).length;
    expect(menuCalls(), 1);
    auth.set(true);
    await tester.pumpAndSettle();
    expect(menuCalls(), 2);
    auth.set(false);
    await tester.pumpAndSettle();
    expect(menuCalls(), 3);
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
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<CatalogRepository>.value(value: CatalogRepository(api)),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ...sessionProviders(api),
      ],
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
