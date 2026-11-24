import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

const _user = {
  'id': 1,
  'role': 'customer',
  'full_name': 'Budi',
  'email': 'budi@x.com',
  'phone': '0812345678901',
};

AuthProvider _make() => AuthProvider(AuthRepository(ApiClient(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) {
          return _json(200, {
            'data': {'token': 'tok', 'expires_at': 'x', 'user': _user}
          });
        }
        if (r.url.path.endsWith('/auth/logout')) return http.Response('', 204);
        return _json(200, {
          'data': {'user': _user, 'merchant': null}
        });
      }),
      baseUrl: 'https://x.test/api/v1',
      readToken: TokenStore.readToken,
    )));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('guest by default; load without token stays guest', () async {
    final p = _make();
    await p.load();
    expect(p.isLoggedIn, isFalse);
  });

  test('login sets user, logout clears', () async {
    final p = _make();
    var notified = 0;
    p.addListener(() => notified++);
    await p.login('budi@x.com', 'abc12345');
    expect(p.isLoggedIn, isTrue);
    expect(p.user!.fullName, 'Budi');
    await p.logout();
    expect(p.isLoggedIn, isFalse);
    expect(await TokenStore.readToken(), isNull);
    expect(notified, greaterThanOrEqualTo(2));
  });

  test('load with saved token fetches user', () async {
    await TokenStore.saveSession('tok', 'budi@x.com');
    final p = _make();
    await p.load();
    expect(p.user!.id, 1);
  });
}
