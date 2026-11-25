import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_router.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/cart_store.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/main.dart';
import 'package:kateringkita_pbl/models/cart_item.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/providers/favorites_provider.dart';
import 'package:kateringkita_pbl/providers/notification_provider.dart';
import 'package:kateringkita_pbl/screens/navigation/main_navigation_screen.dart';
import 'package:kateringkita_pbl/widgets/phone_frame.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _err(int status, String code, String msg) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': msg},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

/// Memasang aplikasi lengkap. [secureValues] dan [savedPrefs] adalah isi
/// penyimpanan perangkat sebelum aplikasi dibuka (mis. token dan keranjang
/// tersimpan, seperti saat halaman web dimuat ulang).
Future<void> _pump(
  WidgetTester tester,
  MockClientHandler h, {
  Map<String, String> secureValues = const {},
  Map<String, Object> savedPrefs = const {},
}) async {
  FlutterSecureStorage.setMockInitialValues(Map.of(secureValues));
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(Map.of(savedPrefs));
  await tester.pumpWidget(
    buildAppProviders(client: MockClient(h), child: const KateringKitaApp()),
  );
}

String? _currentRoute() {
  String? name;
  appNavigatorKey.currentState!.popUntil((r) {
    name = r.settings.name;
    return true;
  });
  return name;
}

void main() {
  testWidgets('akar aplikasi dibungkus PhoneFrame (web: selebar ponsel)', (tester) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    expect(find.byType(PhoneFrame), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('guest with no token: splash goes to main nav', (tester) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
  });

  testWidgets('web dimuat ulang di /order-chat/<kode>: Chat tetap terbuka', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/order-chat/ABC123';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    // Splash menyingkir; Chat tetap di atas dengan tab Pesanan di bawahnya.
    final routeNames = <String?>[];
    appNavigatorKey.currentState!.popUntil((route) {
      routeNames.add(route.settings.name);
      return route.isFirst;
    });
    expect(routeNames, ['/order-chat/ABC123', AppRoutes.mainNav]);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('web dimuat ulang di /notifications: beranda di bawahnya', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AppRoutes.notifications;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    // Splash diganti beranda: [beranda, Notifikasi].
    expect(_currentRoute(), AppRoutes.notifications);
    expect(appNavigatorKey.currentState!.canPop(), isTrue);

    // Kembali dari Notifikasi mendarat di beranda, navigator tidak kosong.
    appNavigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });

  /// Nama semua rute di navigator, dari teratas ke terbawah.
  List<String?> stackNames() {
    final names = <String?>[];
    appNavigatorKey.currentState!.popUntil((route) {
      names.add(route.settings.name);
      return true;
    });
    return names;
  }

  for (final initialRoute in ['/store-profile/dapur-a', '/product-detail/7']) {
    testWidgets('web dimuat ulang di $initialRoute: halaman itu tetap terbuka', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          initialRoute;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await _pump(tester, (r) async => _err(404, 'NOT_FOUND', 'x'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));

      // Splash menyingkir; halaman tetap di atas dengan beranda di bawahnya.
      final routeNames = <String?>[];
      appNavigatorKey.currentState!.popUntil((route) {
        routeNames.add(route.settings.name);
        return route.isFirst;
      });
      expect(routeNames, [initialRoute, AppRoutes.mainNav]);
    });
  }

  for (final (initialRoute, label) in [
    (AppRoutes.mainNav, 'beranda'),
    ('/order-chat/', 'alamat Chat tanpa kode'),
    ('/payment/', 'alamat Bayar tanpa kode'),
    (AppRoutes.payment, 'alamat Bayar lama tanpa kode'),
    ('/store-profile', 'alamat toko tanpa slug'),
    ('/product-detail/', 'alamat menu tanpa id'),
  ]) {
    testWidgets('web dimuat ulang di $label: hanya satu beranda/tab', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          initialRoute;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));

      expect(stackNames(), [AppRoutes.mainNav]);
      expect(appNavigatorKey.currentState!.canPop(), isFalse);
    });
  }

  testWidgets('pembuka biasa dari "/": splash tetap tampil ~2,5 detik', (
    tester,
  ) async {
    var meRequests = 0;
    await _pump(tester, (r) async {
      if (r.url.path.endsWith('/v1/me')) meRequests++;
      return _err(401, 'UNAUTHORIZED', 'x');
    }, secureValues: {'access_token': 'tok', 'session_email': 'a@x.com'});
    await tester.pump(const Duration(seconds: 1));
    expect(_currentRoute(), AppRoutes.splash);
    expect(meRequests, 0); // GET /me baru dikirim setelah jeda 2,5 detik
    expect(find.text('Menyiapkan Dapur Kampus...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
  });

  testWidgets(
    'web dimuat ulang di /payment/<kode>: dalam 100 ms splash sudah dilewati, Bayar KK-1 di atas tab Pesanan',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          AppRoutes.paymentFor('KK-1');
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final order = {
        'code': 'KK-1',
        'status': 'holding',
        'payment_method': 'va',
        'payment_status': 'unpaid',
        'seconds_left': 600,
        'pickup_point': {'id': 2, 'name': 'Perpustakaan Pusat'},
        'items': [
          {
            'menu_id': 7,
            'menu_name': 'Nasi Box',
            'qty': 2,
            'unit_price': 45000,
            'options': [],
            'line_total': 90000,
          },
        ],
        'subtotal': 90000,
        'discount': 0,
        'service_fee': 9000,
        'total': 99000,
        'created_at': '2026-11-12T03:00:00Z',
        'updated_at': '2026-11-12T03:00:00Z',
        'merchant': {'id': 1, 'business_name': 'Dapur A'},
      };
      var meRequests = 0;
      await _pump(tester, (r) async {
        if (r.url.path.endsWith('/v1/me')) meRequests++;
        final data = r.url.path.endsWith('/orders/KK-1')
            ? order
            : r.url.path.endsWith('/v1/me')
            ? {
                'user': {
                  'id': 1,
                  'role': 'customer',
                  'full_name': 'Budi',
                  'email': 'a@x.com',
                  'phone': '0812345678901',
                },
              }
            : [];
        return http.Response(
          jsonEncode({'data': data, 'meta': {'total': 0}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }, secureValues: {'access_token': 'tok', 'session_email': 'a@x.com'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Jauh sebelum 2,5 detik: GET /me sudah dikirim tanpa menunggu jeda dan
      // Bayar KK-1 tampil.
      expect(meRequests, 1);
      expect(find.text('Menyiapkan Dapur Kampus...'), findsNothing);
      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.text('KK-1'), findsWidgets);
      expect(find.text('Buat Nomor Virtual Account'), findsOneWidget);

      // Masih di 100 ms: splash sudah dibuang dari riwayat Navigator, jadi
      // kembali (pop sampai rute terbawah) dari Bayar mendarat di tab Pesanan.
      final routeNames = <String?>[];
      appNavigatorKey.currentState!.popUntil((route) {
        routeNames.add(route.settings.name);
        return route.isFirst;
      });
      expect(routeNames, ['/payment/KK-1', AppRoutes.mainNav]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(stackNames(), [AppRoutes.mainNav]);
      expect(appNavigatorKey.currentState!.canPop(), isFalse);
      expect(
        tester
            .widget<MainNavigationScreen>(find.byType(MainNavigationScreen))
            .initialIndex,
        AppRouter.ordersTabIndex,
      );
    },
  );

  group('web dimuat ulang di /checkout', () {
    const user = {
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi',
      'email': 'a@x.com',
      'phone': '0812345678901',
    };
    final menuJson = {
      'id': 7,
      'name': 'Nasi Box',
      'price': 10000,
      'merchant': {
        'id': 1,
        'slug': 'a',
        'business_name': 'A',
        'is_open': true,
        'pickup_points': [
          {'id': 2, 'name': 'Perpustakaan'},
        ],
      },
      'options': [],
    };
    final savedCart = CartStore.encode([
      CartItem(menu: ProductModel.fromJson(menuJson)),
    ]);

    http.Response ok(Object data) => http.Response(
      jsonEncode({'data': data, 'meta': {'total': 0}}),
      200,
      headers: {'content-type': 'application/json'},
    );

    /// Membuka aplikasi di /checkout dengan token dan keranjang tersimpan;
    /// GET /me baru menjawab setelah 300 ms ([sessionValid] menentukan isinya).
    Future<void> reloadCheckout(
      WidgetTester tester, {
      required bool sessionValid,
    }) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          AppRoutes.checkout;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await _pump(
        tester,
        (r) async {
          final path = r.url.path;
          if (path.endsWith('/v1/me')) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return sessionValid
                ? ok({'user': user})
                : _err(401, 'UNAUTHORIZED', 'x');
          }
          if (path.endsWith('/menus/7')) return ok(menuJson);
          return ok([]);
        },
        secureValues: {'access_token': 'tok', 'session_email': 'a@x.com'},
        savedPrefs: {CartStore.storageKey: savedCart},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // GET /me belum kembali: Login belum boleh dibuka.
      expect(_currentRoute(), AppRoutes.checkout);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('token sah: checkout tampil tanpa Login', (tester) async {
      await reloadCheckout(tester, sessionValid: true);
      expect(_currentRoute(), AppRoutes.checkout);
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Nasi Box'), findsWidgets);
      final ctx = appNavigatorKey.currentContext!;
      expect(ctx.read<AuthProvider>().isLoggedIn, isTrue);
    });

    testWidgets('token tidak sah: Login dibuka, keranjang tersimpan dikosongkan', (
      tester,
    ) async {
      await reloadCheckout(tester, sessionValid: false);
      expect(_currentRoute(), AppRoutes.login);
      final ctx = appNavigatorKey.currentContext!;
      expect(ctx.read<CartProvider>().items, isEmpty);
      expect(
        await SharedPreferencesAsync().getString(CartStore.storageKey),
        isNull,
      );
    });

    testWidgets(
      'dimuat ulang lalu permintaan lain kena 401 sebelum GET /me: keranjang dikosongkan',
      (tester) async {
        final meNeverAnswers = Completer<http.Response>();
        await _pump(
          tester,
          (r) => r.url.path.endsWith('/v1/me')
              ? meNeverAnswers.future
              : Future.value(_err(401, 'UNAUTHORIZED', 'x')),
          secureValues: {'access_token': 'tok', 'session_email': 'a@x.com'},
          savedPrefs: {CartStore.storageKey: savedCart},
        );
        await tester.pump();
        final ctx = appNavigatorKey.currentContext!;
        final cart = ctx.read<CartProvider>();
        expect(cart.items, isNotEmpty); // dipulihkan dari perangkat

        // Token tersimpan ditolak server: sesi dihapus, keranjang ikut kosong.
        await expectLater(
          ctx.read<ApiClient>().get('/orders'),
          throwsA(isA<Object>()),
        );
        await tester.pumpAndSettle();
        expect(_currentRoute(), AppRoutes.login);
        expect(cart.items, isEmpty);
        expect(
          await SharedPreferencesAsync().getString(CartStore.storageKey),
          isNull,
        );
      },
    );
  });

  testWidgets('expired token at splash: guest continues to main nav', (
    tester,
  ) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await TokenStore.saveSession('old', 'a@x.com');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
    expect(await TokenStore.readToken(), isNull);
    final ctx = appNavigatorKey.currentContext!;
    expect(ctx.read<AuthProvider>().isLoggedIn, isFalse);
  });

  testWidgets('authenticated 401 redirects to Login exactly once', (
    tester,
  ) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    await TokenStore.saveSession('tok', 'a@x.com');
    final ctx = appNavigatorKey.currentContext!;
    final repo = ctx.read<AuthProvider>();
    expect(repo.isLoggedIn, isFalse);

    // Dua permintaan berotorisasi bersamaan -> tetap satu redirect.
    final apiClient = Provider.of<ApiClient>(ctx, listen: false);
    Future<Object?> call() async {
      try {
        await apiClient.get('/orders');
        return null;
      } catch (e) {
        return e;
      }
    }

    final results = await Future.wait([call(), call()]);
    await tester.pumpAndSettle();
    for (final e in results) {
      expect(e.toString(), contains('ApiException'));
    }
    expect(_currentRoute(), AppRoutes.login);
    var depth = 0;
    appNavigatorKey.currentState!.popUntil((r) {
      depth++;
      return true;
    });
    expect(depth, 1);
    expect(await TokenStore.readToken(), isNull);
  });

  testWidgets('wrong password shows server message on Login screen', (
    tester,
  ) async {
    await _pump(
      tester,
      (r) async => r.url.path.endsWith('/auth/login')
          ? _err(401, 'UNAUTHORIZED', 'Email/WA atau password salah.')
          : _err(401, 'UNAUTHORIZED', 'x'),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    appNavigatorKey.currentState!.pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a@x.com');
    await tester.enterText(fields.at(1), 'salah123');
    await tester.tap(find.text('Masuk').last);
    await tester.pumpAndSettle();
    expect(find.text('Email/WA atau password salah.'), findsOneWidget);
    expect(_currentRoute(), AppRoutes.login);
  });

  group('sesi tidak valid di tengah jalan', () {
    const user = {
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi',
      'email': 'a@x.com',
      'phone': '0812345678901',
    };
    final menu = ProductModel.fromJson({
      'id': 7,
      'name': 'Nasi Box',
      'price': 10000,
      'merchant': {
        'id': 1,
        'slug': 'a',
        'business_name': 'A',
        'is_open': true,
      },
      'options': [],
    });

    Future<http.Response> handler(http.Request r) async {
      if (r.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'data': {'token': 'tok', 'expires_at': 'x', 'user': user},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path.endsWith('/auth/logout')) return http.Response('', 204);
      // Sesi ditolak hanya oleh /me dan /orders; layar lain (beranda, tab
      // Pesanan yang memuat ulang saat login) mendapat daftar kosong.
      final p = r.url.path;
      if (p.endsWith('/v1/me') || p.endsWith('/v1/orders')) {
        return _err(401, 'UNAUTHORIZED', 'Silakan masuk terlebih dahulu.');
      }
      return http.Response(
        jsonEncode({
          'data': [],
          'meta': {'total': 0},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    Future<BuildContext> loggedIn(WidgetTester tester) async {
      await _pump(tester, handler);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      final ctx = appNavigatorKey.currentContext!;
      await ctx.read<AuthProvider>().login('a@x.com', 'abc12345');
      ctx.read<CartProvider>().add(menu);
      expect(ctx.read<AuthProvider>().isLoggedIn, isTrue);
      expect(await TokenStore.readToken(), 'tok');
      return ctx;
    }

    testWidgets('currentUser 401: AuthProvider & keranjang dikosongkan', (
      tester,
    ) async {
      final ctx = await loggedIn(tester);
      final auth = ctx.read<AuthProvider>();
      final cart = ctx.read<CartProvider>();

      expect(await ctx.read<AuthRepository>().currentUser(), isNull);
      await tester.pumpAndSettle();

      expect(await TokenStore.readToken(), isNull);
      expect(auth.isLoggedIn, isFalse);
      expect(cart.items, isEmpty);
      expect(_currentRoute(), AppRoutes.mainNav);
    });

    testWidgets('auth masih login tapi token hilang: 401 -> Login sekali', (
      tester,
    ) async {
      final ctx = await loggedIn(tester);
      final auth = ctx.read<AuthProvider>();
      final cart = ctx.read<CartProvider>();
      await TokenStore.logout(); // token hilang, AuthProvider belum tahu

      final apiClient = Provider.of<ApiClient>(ctx, listen: false);
      Future<Object?> call() async {
        try {
          await apiClient.get('/orders');
          return null;
        } catch (e) {
          return e;
        }
      }

      final results = await Future.wait([call(), call()]);
      await tester.pumpAndSettle();
      for (final e in results) {
        expect(e.toString(), contains('ApiException'));
      }
      expect(_currentRoute(), AppRoutes.login);
      var depth = 0;
      appNavigatorKey.currentState!.popUntil((r) {
        depth++;
        return true;
      });
      expect(depth, 1);
      expect(auth.isLoggedIn, isFalse);
      expect(cart.items, isEmpty);
    });

    testWidgets('logout mengosongkan keranjang', (tester) async {
      final ctx = await loggedIn(tester);
      await ctx.read<AuthProvider>().logout();
      await tester.pumpAndSettle();
      expect(ctx.read<CartProvider>().items, isEmpty);
      expect(ctx.read<AuthProvider>().isLoggedIn, isFalse);
    });

    testWidgets('logout mengosongkan status favorit sesi', (tester) async {
      final ctx = await loggedIn(tester);
      final favorites = ctx.read<FavoritesProvider>();
      const store = MerchantProfile(
        id: 1,
        slug: 'a',
        businessName: 'A',
        merchantTypeName: 'Katering',
        isOpen: true,
        openTime: '08:00',
        closeTime: '17:00',
        ratingAvg: 0,
        ratingCount: 0,
      );
      await favorites.setFavorite(menu, true);
      await favorites.setFavoriteMerchant(store, true);
      expect(favorites.isFavorite(menu), isTrue);
      expect(favorites.isFavoriteMerchant(store), isTrue);

      await ctx.read<AuthProvider>().logout();
      await tester.pumpAndSettle();
      expect(favorites.isFavorite(menu), isFalse);
      expect(favorites.isFavoriteMerchant(store), isFalse);
    });

    testWidgets('logout mengosongkan lencana notifikasi', (tester) async {
      final ctx = await loggedIn(tester);
      final notifications = ctx.read<NotificationProvider>();
      notifications.setUnread(3);
      await ctx.read<AuthProvider>().logout();
      await tester.pumpAndSettle();
      expect(notifications.unreadCount, 0);
    });
  });
}
