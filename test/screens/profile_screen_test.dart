import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
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
}
