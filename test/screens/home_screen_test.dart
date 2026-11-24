import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
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

  group('titik temu favorit', () {
    const points = {
      'data': [
        {'id': 1, 'name': 'Gerbang Barat', 'description': 'Dekat parkir'},
        {'id': 2, 'name': 'Perpustakaan Pusat', 'description': null},
      ]
    };

    Map<String, dynamic> user(int? fav) => {
          'id': 1,
          'role': 'customer',
          'full_name': 'Budi',
          'email': 'b@x.com',
          'phone': '0812345678901',
          'favorite_pickup_point_id': fav,
        };

    /// AuthProvider asli: login & PATCH /me lewat MockClient.
    Future<(List<http.Request>, AuthProvider)> pump(WidgetTester tester,
        {int? fav, bool login = true, http.Response? patch}) async {
      FlutterSecureStorage.setMockInitialValues({});
      final log = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://x.test/api/v1',
        readToken: TokenStore.readToken,
        client: MockClient((req) async {
          log.add(req);
          final p = req.url.path;
          if (p.endsWith('/auth/login')) {
            return _json({
              'data': {'token': 't', 'expires_at': 'x', 'user': user(fav)}
            });
          }
          if (p.endsWith('/v1/me') && req.method == 'PATCH') {
            if (patch != null) return patch;
            final id = jsonDecode(req.body)['favorite_pickup_point_id'];
            return _json({
              'data': {'user': user(id as int?), 'merchant': null}
            });
          }
          if (p.endsWith('/meta/pickup-points')) return _json(points);
          if (p.endsWith('/meta/categories')) return _json(_cats);
          return _json({'data': [], 'meta': {'total': 0}});
        }),
      );
      final auth = AuthProvider(AuthRepository(api));
      if (login) await auth.login('b@x.com', 'abc12345');
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: CatalogRepository(api)),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ...sessionProviders(api, auth: auth),
        ],
        child: MaterialApp(
          home: const HomeScreen(),
          routes: {
            AppRoutes.login: (c) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      await auth.login('b@x.com', 'abc12345');
                      if (c.mounted) Navigator.pop(c, true);
                    },
                    child: const Text('login-palsu'),
                  ),
                ),
          },
        ),
      ));
      await tester.pumpAndSettle();
      return (log, auth);
    }

    Finder label() => find.byKey(const ValueKey('home-pickup-point'));

    testWidgets('tanpa favorit: ajakan pilih, tanpa teks pengantaran',
        (tester) async {
      await pump(tester);
      expect(find.text('Pilih titik temu favorit ▾'), findsOneWidget);
      expect(find.textContaining('Pengantaran'), findsNothing);
      // Tidak ada data halal/higienis di server: jangan diklaim.
      expect(find.textContaining('halal'), findsNothing);
    });

    testWidgets('favorit dari profil server tampil dengan namanya',
        (tester) async {
      await pump(tester, fav: 2);
      expect(find.text('Titik temu: Perpustakaan Pusat ▾'), findsOneWidget);
    });

    testWidgets('pilih titik -> PATCH /me favorite_pickup_point_id',
        (tester) async {
      final (log, auth) = await pump(tester);
      await tester.tap(label());
      await tester.pumpAndSettle();
      expect(find.text('Titik Temu Favorit'), findsOneWidget);
      await tester.tap(find.text('Gerbang Barat'));
      await tester.pumpAndSettle();

      final patch = log.singleWhere((r) => r.method == 'PATCH');
      expect(patch.url.path, '/api/v1/me');
      expect(jsonDecode(patch.body), {'favorite_pickup_point_id': 1});
      expect(auth.user!.favoritePickupPointId, 1);
      expect(find.text('Titik temu: Gerbang Barat ▾'), findsOneWidget);
      expect(find.text('Titik temu favorit: Gerbang Barat'), findsOneWidget);
    });

    testWidgets('server menolak: pesan kolom, favorit tidak berubah',
        (tester) async {
      final (_, auth) = await pump(tester,
          fav: 2,
          patch: _json({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Data tidak valid.',
              'fields': {
                'favorite_pickup_point_id': ['Titik temu tidak tersedia.']
              }
            }
          }, 400));
      await tester.tap(label());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerbang Barat'));
      await tester.pumpAndSettle();
      expect(find.text('Titik temu tidak tersedia.'), findsOneWidget);
      expect(auth.user!.favoritePickupPointId, 2);
      expect(find.text('Titik temu: Perpustakaan Pusat ▾'), findsOneWidget);
    });

    testWidgets('tamu: diminta masuk dulu, lalu memilih', (tester) async {
      final (log, _) = await pump(tester, login: false);
      await tester.tap(label());
      await tester.pumpAndSettle();
      expect(find.text('Masuk dulu untuk menyimpan titik temu favorit.'),
          findsOneWidget);
      expect(log.where((r) => r.url.path.endsWith('/pickup-points')), isEmpty);
      await tester.tap(find.text('login-palsu'));
      await tester.pumpAndSettle();
      expect(find.text('Titik Temu Favorit'), findsOneWidget);
      await tester.tap(find.text('Perpustakaan Pusat'));
      await tester.pumpAndSettle();
      expect(find.text('Titik temu: Perpustakaan Pusat ▾'), findsOneWidget);
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
