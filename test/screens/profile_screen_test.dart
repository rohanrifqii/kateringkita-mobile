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

import '../support/session.dart';

const _photo = 'https://cdn.x.test/users/1/avatar/a.png';

Map<String, dynamic> _user({String? avatarUrl}) => {
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi Santoso',
      'email': 'budi@x.com',
      'phone': '0812345678901',
      'avatar_url': avatarUrl,
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic> user) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await TokenStore.saveSession('tok', 'budi@x.com');
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    readToken: TokenStore.readToken,
    client: MockClient((r) async => http.Response(
        jsonEncode({
          'data': {'user': user, 'merchant': null}
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'})),
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      Provider<AuthRepository>.value(value: AuthRepository(api)),
      ChangeNotifierProvider<AuthProvider>.value(
          value: FakeAuth(loggedIn: true)),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  ));
  await tester.pumpAndSettle();
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

  testWidgets('tanpa avatar_url: inisial nama, tanpa gambar jaringan',
      (tester) async {
    await _pump(tester, _user());
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('profile-avatar-initials')),
        findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
