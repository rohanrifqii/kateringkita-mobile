import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_info.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/core/password_rules.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _photo = 'https://cdn.x.test/users/1/avatar/a.png';

Map<String, dynamic> _user({String? avatarUrl}) => {
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi Santoso',
      'email': 'budi@x.com',
      'phone': '0812345678901',
      'avatar_url': avatarUrl,
    };

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// [user] null = tamu (tanpa sesi). Selain GET /me, permintaan dicatat di
/// [seen] dan dijawab [handler] (bawaan 200 kosong).
Future<AuthProvider> _pump(
  WidgetTester tester,
  Map<String, dynamic>? user, {
  List<http.Request>? seen,
  MockClientHandler? handler,
  Map<String, WidgetBuilder> routes = const {},
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  if (user != null) await TokenStore.saveSession('tok', 'budi@x.com');
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    readToken: TokenStore.readToken,
    client: MockClient((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/me')) {
        return _json(200, {
          'data': {'user': user, 'merchant': null}
        });
      }
      seen?.add(r);
      return handler == null ? _json(200, {'data': {}}) : handler(r);
    }),
  );
  // Layar tinggi: semua menu & isi lembar terlihat tanpa menggulir.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = AuthRepository(api);
  final auth = AuthProvider(repo);
  await auth.load();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      Provider<AuthRepository>.value(value: repo),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ],
    child: MaterialApp(home: const ProfileScreen(), routes: routes),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Finder _networkAvatar(String url) => find.byWidgetPredicate(
    (w) => w is Image && w.image is NetworkImage &&
        (w.image as NetworkImage).url == url);

void main() {
  testWidgets('header memakai foto dari avatar_url server', (tester) async {
    await _pump(tester, _user(avatarUrl: _photo));
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(_networkAvatar(_photo), findsOneWidget);
    // Gambar belum/gagal dimuat (tes tanpa jaringan): tetap tampil inisial.
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('tanpa bahasa, notifikasi lokal, biometrik, maupun bio palsu',
      (tester) async {
    await _pump(tester, _user());
    for (final gone in [
      'Bahasa',
      'English',
      'Pengaturan Notifikasi',
      'PIN Transaksi & Biometrik aktif',
      'Mahasiswa\nUniversitas Brawijaya',
    ]) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.text('Kelola Profil'), findsOneWidget);
    expect(find.text('Tema Tampilan'), findsOneWidget);

    await tester.tap(find.text('Password & Keamanan'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Password Akun'), findsOneWidget);
    expect(find.text('PIN Transaksi & Biometrik'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('tanpa avatar_url: inisial nama, tanpa gambar jaringan',
      (tester) async {
    await _pump(tester, _user());
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('profile-avatar-initials')),
        findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('tamu: "Tamu" + Masuk/Daftar, tanpa data orang mana pun',
      (tester) async {
    Object? loginArgs;
    var signUpOpened = false;
    await _pump(tester, null, routes: {
      AppRoutes.login: (c) {
        loginArgs = ModalRoute.of(c)!.settings.arguments;
        return Scaffold(appBar: AppBar(), body: const Text('HALAMAN LOGIN'));
      },
      AppRoutes.signUp: (c) {
        signUpOpened = true;
        return const Scaffold(body: Text('HALAMAN DAFTAR'));
      },
    });

    expect(find.text('Tamu'), findsOneWidget);
    for (final gone in [
      'Abdurrahim',
      'A',
      'Kelola Profil',
      'Password & Keamanan',
      'Keluar dari Akun',
    ]) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.textContaining('abdurrahim'), findsNothing);
    expect(find.textContaining('0858'), findsNothing);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('HALAMAN LOGIN'), findsOneWidget);
    expect(loginArgs, {'returnTo': true});
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(signUpOpened, isTrue);
  });

  testWidgets('header ikut berubah saat AuthProvider.user berubah',
      (tester) async {
    final auth = await _pump(tester, _user(),
        handler: (r) async => _json(200, {
              'data': {
                'user': {..._user(), 'full_name': 'Siti Aminah'},
                'merchant': null
              }
            }));
    expect(find.text('Budi Santoso'), findsOneWidget);
    await auth.updateProfile(
        fullName: 'Siti Aminah', phone: '0812345678901', email: 'budi@x.com');
    await tester.pumpAndSettle();
    expect(find.text('Siti Aminah'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('tanpa klaim karangan: rating toko aplikasi, respon CS, Aktif',
      (tester) async {
    await _pump(tester, _user());
    for (final gone in [
      'Beri Rating di App Store',
      'Respon cepat < 2 menit',
      'Aktif',
    ]) {
      expect(find.text(gone), findsNothing);
    }
    expect(find.textContaining('2025'), findsNothing);
    expect(find.text('Hubungi CS WhatsApp'), findsOneWidget);
  });

  testWidgets('FAQ sesuai aplikasi: Midtrans, tanpa tunai/antar/fitur lama',
      (tester) async {
    await _pump(tester, _user());
    await tester.tap(find.text('Pusat Bantuan & FAQ'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    String allText() => tester
        .widgetList<Text>(find.descendant(of: sheet, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join('\n');

    // Buka semua pertanyaan supaya jawabannya ikut diperiksa.
    for (final tile in tester
        .widgetList<ExpansionTile>(find.byType(ExpansionTile))
        .toList()) {
      await tester.tap(find.byWidget(tile.title));
      await tester.pumpAndSettle();
    }
    final text = allText();
    expect(text, contains('Midtrans'));
    expect(text, contains('titik temu'));
    for (final claim in [
      'COD',
      'Tunai saat',
      'OVO',
      'DANA',
      'Mandiri',
      'kurir',
      'ongkir',
      'refund',
      'Holding Timer',
      'Profit Maksimal',
    ]) {
      expect(text.contains(claim), isFalse, reason: 'masih ada "$claim"');
    }
  });

  testWidgets('Tentang: versi dari pubspec, tanpa build karangan',
      (tester) async {
    await _pump(tester, _user());
    await tester.tap(find.text('Tentang KateringKita'));
    await tester.pumpAndSettle();
    expect(find.text('Versi $kAppVersion'), findsOneWidget);
    expect(find.textContaining('Build'), findsNothing);
  });

  testWidgets('ganti password memakai aturan server (8–72, huruf & angka)',
      (tester) async {
    final seen = <http.Request>[];
    await _pump(tester, _user(), seen: seen);
    await tester.tap(find.text('Password & Keamanan'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);

    Future<void> submit(String pw) async {
      await tester.enterText(fields.at(0), 'lama1234');
      await tester.enterText(fields.at(1), pw);
      await tester.enterText(fields.at(2), pw);
      await tester.tap(find.text('Simpan Password Baru'));
      await tester.pumpAndSettle();
    }

    for (final bad in ['abc1234', 'abcdefgh', '12345678']) {
      await submit(bad);
      expect(find.text(kPasswordRuleMessage), findsOneWidget, reason: bad);
    }
    expect(seen, isEmpty);

    await submit('abc12345');
    expect(seen.single.method, 'PUT');
    expect(seen.single.url.path, '/api/v1/me/password');
    expect(jsonDecode(seen.single.body),
        {'current_password': 'lama1234', 'new_password': 'abc12345'});
  });
}
