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

AuthRepository _repo(MockClientHandler h, {MockClientHandler? upload}) =>
    AuthRepository(
      ApiClient(
        client: MockClient(h),
        baseUrl: 'https://x.test/api/v1',
        readToken: TokenStore.readToken,
      ),
      uploadClient: upload == null ? null : MockClient(upload),
    );

const _uploadUrl = 'https://acc.r2.cloudflarestorage.com/bucket/users/1/'
    'avatar/a.png?X-Amz-Signature=abc';
const _publicUrl = 'https://cdn.x.test/users/1/avatar/a.png';

Map<String, dynamic> _presign() => {
      'data': {
        'upload_url': _uploadUrl,
        'public_url': _publicUrl,
        'expires_at': '2026-11-13T10:05:00.000Z',
      }
    };

Map<String, dynamic> _me([Map<String, dynamic> extra = const {}]) => {
      'data': {
        'user': {..._user, ...extra},
        'merchant': null,
      }
    };

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

  group('uploadAvatar', () {
    final bytes = Uint8List.fromList(List.generate(321, (i) => i % 256));

    test(
        'POST /me/avatar, PUT ke upload_url tanpa Authorization, '
        'lalu PATCH avatar_url', () async {
      await TokenStore.saveSession('tok', 'budi@x.com');
      final api = <http.Request>[];
      final puts = <http.Request>[];
      final repo = _repo((r) async {
        api.add(r);
        if (r.method == 'POST') return _json(200, _presign());
        return _json(200, _me({'avatar_url': _publicUrl}));
      }, upload: (r) async {
        puts.add(r);
        return http.Response('', 200);
      });

      final u = await repo.uploadAvatar(fileName: 'foto.png', bytes: bytes);

      expect(api.map((r) => '${r.method} ${r.url.path}'),
          ['POST /api/v1/me/avatar', 'PATCH /api/v1/me']);
      expect(api[0].headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(api[0].body),
          {'content_type': 'image/png', 'size': 321});
      expect(jsonDecode(api[1].body), {'avatar_url': _publicUrl});

      final put = puts.single;
      expect(put.method, 'PUT');
      expect(put.url.toString(), _uploadUrl);
      expect(put.headers['Content-Type'], 'image/png');
      expect(put.headers.containsKey('Authorization'), isFalse);
      expect(put.contentLength, 321);
      expect(put.bodyBytes, bytes);

      expect(u.avatarUrl, _publicUrl);
    });

    test('tipe dari ekstensi: jpg/jpeg/JPG -> image/jpeg, webp -> image/webp',
        () async {
      final types = <String>[];
      final repo = _repo((r) async {
        if (r.method == 'POST') {
          types.add(jsonDecode(r.body)['content_type'] as String);
          return _json(200, _presign());
        }
        return _json(200, _me());
      }, upload: (r) async {
        expect(r.headers['Content-Type'], types.last);
        return http.Response('', 200);
      });
      for (final name in ['a.jpg', 'b.jpeg', 'C.JPG', 'd.webp']) {
        await repo.uploadAvatar(fileName: name, bytes: bytes);
      }
      expect(types, ['image/jpeg', 'image/jpeg', 'image/jpeg', 'image/webp']);
    });

    test('format selain JPG/PNG/WebP ditolak sebelum ada permintaan', () async {
      var called = 0;
      final repo = _repo((r) async {
        called++;
        return _json(200, _presign());
      }, upload: (r) async {
        called++;
        return http.Response('', 200);
      });
      for (final name in ['a.gif', 'b.heic', 'tanpa-ekstensi']) {
        await expectLater(
          repo.uploadAvatar(fileName: name, bytes: bytes),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              'Format foto harus JPG, PNG, atau WebP.')),
        );
      }
      expect(called, 0);
    });

    test('lebih dari 5 MB ditolak sebelum ada permintaan; tepat 5 MB lolos',
        () async {
      var called = 0;
      final repo = _repo((r) async {
        called++;
        if (r.method == 'POST') return _json(200, _presign());
        return _json(200, _me());
      }, upload: (r) async => http.Response('', 200));
      await expectLater(
        repo.uploadAvatar(fileName: 'a.jpg', bytes: Uint8List(5242881)),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Ukuran foto maksimal 5 MB.')),
      );
      expect(called, 0);
      await repo.uploadAvatar(fileName: 'a.jpg', bytes: Uint8List(5242880));
      expect(called, 2);
    });

    test('503 dari server: pesan server diteruskan, tanpa PUT/PATCH', () async {
      final seen = <String>[];
      final repo = _repo((r) async {
        seen.add(r.method);
        return _json(503, {
          'error': {
            'code': 'SERVICE_UNAVAILABLE',
            'message': 'Unggah foto belum tersedia. Coba lagi nanti.'
          }
        });
      }, upload: (r) async {
        seen.add('PUT');
        return http.Response('', 200);
      });
      await expectLater(
        repo.uploadAvatar(fileName: 'a.png', bytes: bytes),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Unggah foto belum tersedia. Coba lagi nanti.')),
      );
      expect(seen, ['POST']);
    });

    test('429 dari server: pesan batas unggahan diteruskan', () async {
      final repo = _repo(
          (r) async => _json(429, {
                'error': {
                  'code': 'RATE_LIMITED',
                  'message':
                      'Terlalu banyak unggahan. Coba lagi beberapa menit lagi.'
                }
              }),
          upload: (r) async => http.Response('', 200));
      await expectLater(
        repo.uploadAvatar(fileName: 'a.png', bytes: bytes),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Terlalu banyak unggahan. Coba lagi beberapa menit lagi.')),
      );
    });

    test('galat kolom dari server memakai pesan kolomnya', () async {
      final repo = _repo(
          (r) async => _json(400, {
                'error': {
                  'code': 'VALIDATION_ERROR',
                  'message': 'Data tidak valid.',
                  'fields': {
                    'size': ['Ukuran foto maksimal 5 MB.']
                  }
                }
              }),
          upload: (r) async => http.Response('', 200));
      await expectLater(
        repo.uploadAvatar(fileName: 'a.png', bytes: bytes),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Ukuran foto maksimal 5 MB.')),
      );
    });

    test('PUT ke R2 gagal (non-2xx atau jaringan): pesan ramah, tanpa PATCH',
        () async {
      for (final fail in <Future<http.Response> Function()>[
        () async => http.Response('<Error>SignatureDoesNotMatch</Error>', 403),
        () async => throw http.ClientException('offline'),
      ]) {
        final methods = <String>[];
        final repo = _repo((r) async {
          methods.add(r.method);
          return _json(200, _presign());
        }, upload: (r) => fail());
        await expectLater(
          repo.uploadAvatar(fileName: 'a.png', bytes: bytes),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              'Gagal mengunggah foto. Coba lagi.')),
        );
        expect(methods, ['POST']);
      }
    });

    test('PATCH menolak avatar_url: pesan kolom avatar_url', () async {
      final repo = _repo((r) async {
        if (r.method == 'POST') return _json(200, _presign());
        return _json(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid.',
            'fields': {
              'avatar_url': ['Foto tidak valid. Unggah ulang foto.']
            }
          }
        });
      }, upload: (r) async => http.Response('', 200));
      await expectLater(
        repo.uploadAvatar(fileName: 'a.png', bytes: bytes),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Foto tidak valid. Unggah ulang foto.')),
      );
    });
  });

  test('removeAvatar: PATCH /me avatar_url kosong, user tanpa foto', () async {
    late http.Request seen;
    final repo = _repo((r) async {
      seen = r;
      return _json(200, _me({'avatar_url': null}));
    });
    final u = await repo.removeAvatar();
    expect(seen.method, 'PATCH');
    expect(seen.url.path, '/api/v1/me');
    expect(jsonDecode(seen.body), {'avatar_url': ''});
    expect(u.avatarUrl, isNull);
  });

  test('logout ignores network error and clears session', () async {
    await TokenStore.saveSession('tok', 'a@x.com');
    final repo = _repo((r) async => throw http.ClientException('offline'));
    await repo.logout();
    expect(await TokenStore.readToken(), isNull);
  });
}
