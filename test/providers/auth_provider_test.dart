import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
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

  test('setFavoritePickupPoint memperbarui user dari jawaban server',
      () async {
    final seen = <http.Request>[];
    final p = AuthProvider(AuthRepository(ApiClient(
      client: MockClient((r) async {
        seen.add(r);
        if (r.url.path.endsWith('/auth/login')) {
          return _json(200, {
            'data': {'token': 'tok', 'expires_at': 'x', 'user': _user}
          });
        }
        return _json(200, {
          'data': {
            'user': {..._user, 'favorite_pickup_point_id': 3},
            'merchant': null
          }
        });
      }),
      baseUrl: 'https://x.test/api/v1',
      readToken: TokenStore.readToken,
    )));
    await p.login('budi@x.com', 'abc12345');
    expect(p.user!.favoritePickupPointId, isNull);
    var notified = 0;
    p.addListener(() => notified++);
    await p.setFavoritePickupPoint(3);
    expect(seen.last.method, 'PATCH');
    expect(p.user!.favoritePickupPointId, 3);
    expect(notified, 1);
  });

  group('perubahan profil memperbarui user', () {
    const photo = 'https://cdn.x.test/users/1/avatar/a.png';

    /// Login dulu, lalu PATCH /me dijawab [patch]; POST /me/avatar &
    /// PUT R2 selalu sukses.
    Future<(AuthProvider, List<http.Request>)> loggedIn(
        Future<http.Response> Function(http.Request r) patch) async {
      final seen = <http.Request>[];
      final p = AuthProvider(AuthRepository(
        ApiClient(
          client: MockClient((r) async {
            seen.add(r);
            if (r.url.path.endsWith('/auth/login')) {
              return _json(200, {
                'data': {'token': 'tok', 'expires_at': 'x', 'user': _user}
              });
            }
            if (r.url.path.endsWith('/me/avatar')) {
              return _json(200, {
                'data': {
                  'upload_url': 'https://r2.x.test/a.png?sig=1',
                  'public_url': photo,
                  'expires_at': 'x'
                }
              });
            }
            return patch(r);
          }),
          baseUrl: 'https://x.test/api/v1',
          readToken: TokenStore.readToken,
        ),
        uploadClient: MockClient((r) async => http.Response('', 200)),
      ));
      await p.login('budi@x.com', 'abc12345');
      seen.clear();
      return (p, seen);
    }

    http.Response me(Map<String, dynamic> extra) => _json(200, {
          'data': {
            'user': {..._user, ...extra},
            'merchant': null
          }
        });

    test('updateProfile: PATCH /me lalu user & listener ikut baru', () async {
      final (p, seen) = await loggedIn(
          (r) async => me({'full_name': 'Budi S', 'phone': '0899999999'}));
      var notified = 0;
      p.addListener(() => notified++);
      await p.updateProfile(
          fullName: 'Budi S', phone: '0899999999', email: 'budi@x.com',
          currentPassword: 'abc12345');
      expect(seen.single.method, 'PATCH');
      expect(jsonDecode(seen.single.body), {
        'full_name': 'Budi S',
        'phone': '0899999999',
        'current_password': 'abc12345',
      });
      expect(p.user!.fullName, 'Budi S');
      expect(p.user!.phone, '0899999999');
      expect(notified, 1);
    });

    test('updateProfile ditolak server: user lama tetap, galat diteruskan',
        () async {
      final (p, _) = await loggedIn((r) async => _json(400, {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Data tidak valid.',
              'fields': {
                'current_password': ['Kata sandi lama salah.']
              }
            }
          }));
      var notified = 0;
      p.addListener(() => notified++);
      await expectLater(
        p.updateProfile(
            fullName: 'Budi', phone: '0899999999', email: 'budi@x.com',
            currentPassword: 'salah'),
        throwsA(isA<ApiException>()),
      );
      expect(p.user!.phone, '0812345678901');
      expect(notified, 0);
    });

    test('uploadAvatar & removeAvatar memperbarui avatarUrl', () async {
      var avatar = photo as String?;
      final (p, _) = await loggedIn((r) async => me({'avatar_url': avatar}));
      await p.uploadAvatar(
          fileName: 'a.png', bytes: Uint8List.fromList([1, 2, 3]));
      expect(p.user!.avatarUrl, photo);

      avatar = null;
      await p.removeAvatar();
      expect(p.user!.avatarUrl, isNull);
    });

    test('tanpa sesi: menolak tanpa permintaan', () async {
      var called = false;
      final p = AuthProvider(AuthRepository(ApiClient(
        client: MockClient((r) async {
          called = true;
          return _json(200, {});
        }),
        baseUrl: 'https://x.test/api/v1',
      )));
      await expectLater(
        p.updateProfile(fullName: 'A', phone: '0812345678', email: 'a@x.com'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      await expectLater(p.removeAvatar(), throwsA(isA<ApiException>()));
      expect(called, isFalse);
    });
  });

  test('load with saved token fetches user', () async {
    await TokenStore.saveSession('tok', 'budi@x.com');
    final p = _make();
    await p.load();
    expect(p.user!.id, 1);
  });
}
