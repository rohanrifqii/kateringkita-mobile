import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/favorites_provider.dart';
import 'package:kateringkita_pbl/screens/liked/liked_screen.dart';
import 'package:provider/provider.dart';

import '../support/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _card(int id, String name, {bool open = true}) => {
      'id': id,
      'name': name,
      'price': 12000,
      'merchant': {
        'id': 1,
        'slug': 'dapur-a',
        'business_name': 'Dapur A',
        'is_open': open,
      },
      'is_favorite': true,
    };

Object _page(List<Map<String, dynamic>> items, {int? total}) => {
      'data': items,
      'meta': {'page': 1, 'limit': 50, 'total': total ?? items.length},
    };

Widget _wrap(Future<http.Response> Function(http.Request) handler,
    {FakeAuth? auth, Map<String, WidgetBuilder> routes = const {}}) {
  final api = ApiClient(
      baseUrl: 'https://x.test/api/v1', client: MockClient(handler));
  return MultiProvider(
    providers: sessionProviders(api, auth: auth ?? FakeAuth(loggedIn: true)),
    child: MaterialApp(home: const LikedScreen(), routes: routes),
  );
}

void main() {
  testWidgets('tamu: ajakan masuk, tanpa permintaan', (tester) async {
    final seen = <Uri>[];
    var loginOpened = false;
    await tester.pumpWidget(_wrap((req) async {
      seen.add(req.url);
      return _json(_page([]));
    }, auth: FakeAuth(), routes: {
      AppRoutes.login: (_) {
        loginOpened = true;
        return const Scaffold();
      },
    }));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk melihat favoritmu'), findsOneWidget);
    expect(seen, isEmpty);
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(loginOpened, isTrue);
  });

  testWidgets('pembeli: daftar dari GET /me/favorites', (tester) async {
    final seen = <Uri>[];
    await tester.pumpWidget(_wrap((req) async {
      seen.add(req.url);
      return _json(_page([
        _card(7, 'Nasi Box'),
        _card(8, 'Es Teh', open: false),
      ]));
    }));
    await tester.pumpAndSettle();
    expect(seen.single.path, '/api/v1/me/favorites');
    expect(seen.single.queryParameters['page'], '1');
    expect(find.text('2 Menu Favorit Tersimpan'), findsOneWidget);
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Toko sedang tutup'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
  });

  testWidgets('kosong: pesan belum ada favorit', (tester) async {
    await tester.pumpWidget(_wrap((req) async => _json(_page([]))));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada menu favorit'), findsOneWidget);
    expect(find.text('0 Menu Favorit Tersimpan'), findsOneWidget);
  });

  testWidgets('galat: pesan server + Coba Lagi memuat ulang', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap((req) async {
      calls++;
      if (calls == 1) {
        return _json({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Server sibuk.'}
        }, 500);
      }
      return _json(_page([_card(7, 'Nasi Box')]));
    }));
    await tester.pumpAndSettle();
    expect(find.text('Server sibuk.'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('hapus favorit: langsung hilang, DELETE, lalu muat ulang',
      (tester) async {
    final methods = <String>[];
    var removed = false;
    await tester.pumpWidget(_wrap((req) async {
      methods.add('${req.method} ${req.url.path}');
      if (req.method == 'DELETE') {
        removed = true;
        return http.Response('', 204);
      }
      return _json(_page([
        if (!removed) _card(7, 'Nasi Box'),
        _card(8, 'Es Teh'),
      ]));
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_rounded).first);
    await tester.pump();
    expect(find.text('Nasi Box'), findsNothing);
    expect(find.text('1 Menu Favorit Tersimpan'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(methods, [
      'GET /api/v1/me/favorites',
      'DELETE /api/v1/me/favorites/7',
      'GET /api/v1/me/favorites',
    ]);
    expect(find.text('Nasi Box'), findsNothing);
    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Dihapus dari favorit: Nasi Box'), findsOneWidget);
  });

  testWidgets('hapus gagal: menu muncul lagi + pesan galat', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(_wrap((req) async {
      if (req.method == 'DELETE') {
        await gate.future;
        return _json({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Gagal menyimpan.'}
        }, 500);
      }
      return _json(_page([_card(7, 'Nasi Box')]));
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    expect(find.text('Nasi Box'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(find.text('Gagal menyimpan.'), findsOneWidget);
  });

  testWidgets('keluar: daftar dibuang; masuk lagi memuat ulang',
      (tester) async {
    final auth = FakeAuth(loggedIn: true);
    var calls = 0;
    await tester.pumpWidget(_wrap((req) async {
      calls++;
      return _json(_page([_card(7, 'Nasi Box')]));
    }, auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsOneWidget);

    auth.set(false);
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsNothing);
    expect(find.text('Masuk untuk melihat favoritmu'), findsOneWidget);

    auth.set(true);
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('favorit ditambah di layar lain: daftar dimuat ulang',
      (tester) async {
    var withNew = false;
    late BuildContext ctx;
    await tester.pumpWidget(_wrap((req) async {
      if (req.method == 'PUT') {
        withNew = true;
        return http.Response('', 204);
      }
      return _json(_page([
        _card(7, 'Nasi Box'),
        if (withNew) _card(9, 'Risoles'),
      ]));
    }));
    await tester.pumpAndSettle();
    expect(find.text('Risoles'), findsNothing);

    // Mis. hati ditekan di detail menu (rute lain, provider yang sama).
    ctx = tester.element(find.byType(LikedScreen));
    final risoles =
        ProductModel.fromJson({..._card(9, 'Risoles'), 'is_favorite': false});
    await ctx.read<FavoritesProvider>().setFavorite(risoles, true);
    await tester.pumpAndSettle();
    expect(find.text('Risoles'), findsOneWidget);
    expect(find.text('2 Menu Favorit Tersimpan'), findsOneWidget);
  });

  group('segmen Toko (Dapur Favorit)', () {
    Map<String, dynamic> store(int id, String name, {bool open = true}) => {
          'id': id,
          'slug': 'dapur-$id',
          'business_name': name,
          'description': null,
          'logo_url': null,
          'merchant_type': {'id': 1, 'name': 'Katering'},
          'is_open': open,
          'open_time': '08:00',
          'close_time': '17:00',
          'rating_avg': 4.6,
          'rating_count': 8,
          'pickup_points': [],
          'is_favorite': true,
        };

    Object stores(List<Map<String, dynamic>> items) => {
          'data': items,
          'meta': {'page': 1, 'limit': 50, 'total': items.length},
        };

    Future<void> openToko(WidgetTester tester) async {
      await tester.tap(find.text('Toko'));
      await tester.pumpAndSettle();
    }

    testWidgets('memuat GET /me/favorite-merchants saat segmen dibuka',
        (tester) async {
      final seen = <Uri>[];
      String? storeRoute;
      await tester.pumpWidget(_wrap((req) async {
        seen.add(req.url);
        if (req.url.path.endsWith('/me/favorite-merchants')) {
          return _json(stores([
            store(3, 'Dapur Bu Tima'),
            store(4, 'Diego Katering', open: false),
          ]));
        }
        return _json(_page([]));
      }, routes: {
        AppRoutes.storeProfileFor('dapur-4'): (c) {
          storeRoute = ModalRoute.of(c)?.settings.name;
          return const Scaffold(body: Text('layar-toko'));
        },
      }));
      await tester.pumpAndSettle();
      expect(seen.where((u) => u.path.contains('favorite-merchants')), isEmpty);

      await openToko(tester);
      final q = seen.singleWhere((u) => u.path.contains('favorite-merchants'));
      expect(q.queryParameters, {'page': '1', 'limit': '50'});
      expect(find.text('2 Dapur Favorit Tersimpan'), findsOneWidget);
      expect(find.text('Dapur Bu Tima'), findsOneWidget);
      expect(find.textContaining('Tutup 08:00–17:00 WIB'), findsOneWidget);

      await tester.tap(find.text('Diego Katering'));
      await tester.pumpAndSettle();
      expect(find.text('layar-toko'), findsOneWidget);
      expect(storeRoute, '/store-profile/dapur-4');
    });

    testWidgets('hapus toko: langsung hilang, DELETE, muat ulang',
        (tester) async {
      final calls = <String>[];
      var removed = false;
      await tester.pumpWidget(_wrap((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'DELETE') {
          removed = true;
          return http.Response('', 204);
        }
        if (req.url.path.endsWith('/me/favorite-merchants')) {
          return _json(stores([
            if (!removed) store(3, 'Dapur Bu Tima'),
            store(4, 'Diego Katering'),
          ]));
        }
        return _json(_page([]));
      }));
      await tester.pumpAndSettle();
      await openToko(tester);
      await tester.tap(find.byTooltip('Hapus dari Dapur Favorit').first);
      await tester.pump();
      expect(find.text('Dapur Bu Tima'), findsNothing);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.contains('favorite-merchants')), [
        'GET /api/v1/me/favorite-merchants',
        'DELETE /api/v1/me/favorite-merchants/3',
        'GET /api/v1/me/favorite-merchants',
      ]);
      expect(find.text('1 Dapur Favorit Tersimpan'), findsOneWidget);
    });

    testWidgets('hapus gagal: toko muncul lagi + pesan', (tester) async {
      await tester.pumpWidget(_wrap((req) async {
        if (req.method == 'DELETE') {
          return _json({
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Gagal menyimpan.'}
          }, 500);
        }
        if (req.url.path.endsWith('/me/favorite-merchants')) {
          return _json(stores([store(3, 'Dapur Bu Tima')]));
        }
        return _json(_page([]));
      }));
      await tester.pumpAndSettle();
      await openToko(tester);
      await tester.tap(find.byTooltip('Hapus dari Dapur Favorit'));
      await tester.pumpAndSettle();
      expect(find.text('Dapur Bu Tima'), findsOneWidget);
      expect(find.text('Gagal menyimpan.'), findsOneWidget);
    });

    testWidgets('kosong, galat + Coba Lagi', (tester) async {
      var n = 0;
      await tester.pumpWidget(_wrap((req) async {
        if (req.url.path.endsWith('/me/favorite-merchants')) {
          n++;
          if (n == 1) {
            return _json({
              'error': {'code': 'INTERNAL_ERROR', 'message': 'Server sibuk.'}
            }, 500);
          }
          return _json(stores([]));
        }
        return _json(_page([]));
      }));
      await tester.pumpAndSettle();
      await openToko(tester);
      expect(find.text('Server sibuk.'), findsOneWidget);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada Dapur Favorit'), findsOneWidget);
    });

    testWidgets('keluar: daftar toko dibuang, ajakan masuk', (tester) async {
      final auth = FakeAuth(loggedIn: true);
      await tester.pumpWidget(_wrap((req) async {
        if (req.url.path.endsWith('/me/favorite-merchants')) {
          return _json(stores([store(3, 'Dapur Bu Tima')]));
        }
        return _json(_page([]));
      }, auth: auth));
      await tester.pumpAndSettle();
      await openToko(tester);
      expect(find.text('Dapur Bu Tima'), findsOneWidget);
      auth.set(false);
      await tester.pumpAndSettle();
      expect(find.text('Dapur Bu Tima'), findsNothing);
      expect(find.text('Masuk untuk melihat favoritmu'), findsOneWidget);
    });
  });
}
