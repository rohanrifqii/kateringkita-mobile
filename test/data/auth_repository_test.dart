import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';

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

AuthRepository _repo(MockClientHandler h) => AuthRepository(ApiClient(
      client: MockClient(h),
      baseUrl: 'https://x.test/api/v1',
      readToken: TokenStore.readToken,
    ));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('login sends body and saves token', () async {
    final repo = _repo((r) async {
      expect(r.url.path, '/api/v1/auth/login');
      expect(jsonDecode(r.body), {
        'identifier': '0812345678901',
        'password': 'abc12345',
        'client': 'mobile'
      });
      return _json(200, {
        'data': {'token': 'tok', 'expires_at': 'x', 'user': _user}
      });
    });
    final u = await repo.login(identifier: '0812345678901', password: 'abc12345');
    expect(u.fullName, 'Budi');
    expect(await TokenStore.readToken(), 'tok');
    expect(await TokenStore.readSessionEmail(), 'budi@x.com');
  });

  test('login 401 throws ApiException with message', () async {
    final repo = _repo((r) async => _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Email/WA atau password salah.'}
        }));
    expect(
      repo.login(identifier: 'a', password: 'b'),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', 'Email/WA atau password salah.')),
    );
  });

  test('register 409 -> Data sudah terdaftar.', () async {
    final repo = _repo((r) async {
      expect(r.url.path, '/api/v1/auth/customer/register');
      return _json(409, {
        'error': {'code': 'CONFLICT', 'message': 'Data sudah terdaftar.'}
      });
    });
    expect(
      repo.register(
          fullName: 'B', email: 'b@x.com', phone: '0812345678', password: 'abc12345'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Data sudah terdaftar.')),
    );
  });

  test('currentUser without token returns null, no request', () async {
    var called = false;
    final repo = _repo((r) async {
      called = true;
      return _json(200, {});
    });
    expect(await repo.currentUser(), isNull);
    expect(called, isFalse);
  });

  test('currentUser 401 returns null and clears token', () async {
    await TokenStore.saveSession('tok', 'a@x.com');
    final repo = _repo((r) async => _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'}
        }));
    expect(await repo.currentUser(), isNull);
    expect(await TokenStore.readToken(), isNull);
  });

  test('currentUser 401 calls onSessionInvalid once; 500 does not', () async {
    await TokenStore.saveSession('tok', 'a@x.com');
    var invalid = 0;
    var status = 401;
    final repo = AuthRepository(
      ApiClient(
        client: MockClient((r) async => _json(status, {
              'error': {'code': 'X', 'message': 'x'}
            })),
        baseUrl: 'https://x.test/api/v1',
        readToken: TokenStore.readToken,
      ),
      onSessionInvalid: () => invalid++,
    );
    expect(await repo.currentUser(), isNull);
    expect(invalid, 1);

    await TokenStore.saveSession('tok', 'a@x.com');
    status = 500;
    await expectLater(repo.currentUser(), throwsA(isA<ApiException>()));
    expect(invalid, 1);
    expect(await TokenStore.readToken(), 'tok');
  });

  test('currentUser parses /me', () async {
    await TokenStore.saveSession('tok', 'a@x.com');
    final repo = _repo((r) async {
      expect(r.headers['Authorization'], 'Bearer tok');
      return _json(200, {
        'data': {'user': _user, 'merchant': null}
      });
    });
    expect((await repo.currentUser())!.id, 1);
  });

  test('resetPassword sends email, code, password', () async {
    final repo = _repo((r) async {
      expect(r.url.path, '/api/v1/auth/password/reset');
      expect(jsonDecode(r.body),
          {'email': 'a@x.com', 'code': '123456', 'password': 'abc12345'});
      return _json(200, {
        'data': {'ok': true}
      });
    });
    await repo.resetPassword(
        email: 'a@x.com', code: '123456', password: 'abc12345');
  });

  test('setFavoritePickupPoint: PATCH /me hanya favorite_pickup_point_id',
      () async {
    late http.Request seen;
    final repo = _repo((r) async {
      seen = r;
      return _json(200, {
        'data': {
          'user': {..._user, 'favorite_pickup_point_id': 4},
          'merchant': null,
        }
      });
    });
    final u = await repo.setFavoritePickupPoint(4);
    expect(seen.method, 'PATCH');
    expect(seen.url.path, '/api/v1/me');
    expect(jsonDecode(seen.body), {'favorite_pickup_point_id': 4});
    expect(u.favoritePickupPointId, 4);
  });

  test('setFavoritePickupPoint(null) mengirim null untuk menghapus', () async {
    late http.Request seen;
    final repo = _repo((r) async {
      seen = r;
      return _json(200, {
        'data': {'user': _user, 'merchant': null}
      });
    });
    final u = await repo.setFavoritePickupPoint(null);
    expect(jsonDecode(seen.body), {'favorite_pickup_point_id': null});
    expect(u.favoritePickupPointId, isNull);
  });

  test('setFavoritePickupPoint: titik tidak aktif -> galat kolom', () async {
    final repo = _repo((r) async => _json(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid.',
            'fields': {
              'favorite_pickup_point_id': ['Titik temu tidak tersedia.']
            }
          }
        }));
    await expectLater(
      repo.setFavoritePickupPoint(99),
      throwsA(isA<ApiException>().having(
          (e) => e.field('favorite_pickup_point_id'),
          'field',
          'Titik temu tidak tersedia.')),
    );
  });

  test('logout ignores network error and clears session', () async {
    await TokenStore.saveSession('tok', 'a@x.com');
    final repo = _repo((r) async => throw http.ClientException('offline'));
    await repo.logout();
    expect(await TokenStore.readToken(), isNull);
  });
}
