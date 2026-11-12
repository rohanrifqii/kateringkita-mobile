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
    expect(find.text('Masuk untuk melihat menu favoritmu'), findsOneWidget);
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
    expect(find.text('Masuk untuk melihat menu favoritmu'), findsOneWidget);

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
}
