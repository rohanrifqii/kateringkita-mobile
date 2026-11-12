import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

ApiClient _make(MockClientHandler h,
        {Future<String?> Function()? readToken,
        Future<void> Function()? onUnauthorized,
        Duration? timeout}) =>
    ApiClient(
      client: MockClient(h),
      baseUrl: 'https://x.test/api/v1',
      readToken: readToken,
      onUnauthorized: onUnauthorized,
      timeout: timeout ?? const Duration(seconds: 15),
    );

void main() {
  test('get parses data and meta', () async {
    final c = _make((r) async {
      expect(r.url.toString(), 'https://x.test/api/v1/menus');
      return _json(200, {
        'data': [1],
        'meta': {'page': 1, 'limit': 20, 'total': 1}
      });
    });
    final res = await c.get('/menus');
    expect(res.data, [1]);
    expect(res.meta!['total'], 1);
    expect(res.status, 200);
  });

  test('Authorization header present when token exists', () async {
    final c = _make((r) async {
      expect(r.headers['Authorization'], 'Bearer abc');
      return _json(200, {'data': null});
    }, readToken: () async => 'abc');
    await c.get('/x');
  });

  test('no Authorization header when token null', () async {
    final c = _make((r) async {
      expect(r.headers.containsKey('Authorization'), isFalse);
      return _json(200, {'data': null});
    }, readToken: () async => null);
    await c.get('/x');
  });

  test('400 throws ApiException with fields', () async {
    final c = _make((r) async => _json(400, {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Data tidak valid.',
            'fields': {
              'phone': ['Nomor HP harus diawali 08 dan 10–13 digit.']
            }
          }
        }));
    try {
      await c.post('/x', body: {});
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 400);
      expect(e.code, 'VALIDATION_ERROR');
      expect(e.field('phone'), 'Nomor HP harus diawali 08 dan 10–13 digit.');
      expect(e.field('lain'), isNull);
    }
  });

  test('409 without fields gives empty map', () async {
    final c = _make((r) async => _json(409, {
          'error': {'code': 'CONFLICT', 'message': 'Bentrok.'}
        }));
    try {
      await c.get('/x');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(e.fields, isEmpty);
      expect(e.message, 'Bentrok.');
    }
  });

  Future<int> run401(
      {String? token, bool handle = true}) async {
    var n = 0;
    final c = _make(
        (r) async => _json(401, {
              'error': {'code': 'UNAUTHORIZED', 'message': 'Sesi habis.'}
            }),
        readToken: () async => token,
        onUnauthorized: () async => n++);
    await expectLater(
        c.get('/x', handleUnauthorized: handle),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    return n;
  }

  test('401 with token calls onUnauthorized once then throws', () async {
    expect(await run401(token: 't'), 1);
  });

  test('401 without token still calls onUnauthorized (handler decides)',
      () async {
    expect(await run401(), 1);
  });

  test('401 without token and handleUnauthorized false does not call',
      () async {
    expect(await run401(handle: false), 0);
  });

  test('401 with token and handleUnauthorized false does not call', () async {
    expect(await run401(token: 't', handle: false), 0);
  });

  test('204 returns null data', () async {
    final c = _make((r) async => http.Response('', 204));
    final res = await c.delete('/x');
    expect(res.data, isNull);
    expect(res.status, 204);
  });

  test('SocketException maps to NETWORK', () async {
    final c = _make((r) async => throw const SocketException('down'));
    await expectLater(
        c.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 0)
            .having((e) => e.code, 'code', 'NETWORK')
            .having((e) => e.message, 'message', 'Tidak ada koneksi internet.')));
  });

  for (final (name, err) in [
    ('HandshakeException', const HandshakeException('bad cert')),
    ('TlsException', const TlsException('tls')),
    ('HttpException', const HttpException('closed')),
  ]) {
    test('$name maps to NETWORK', () async {
      final c = _make((r) async => throw err);
      await expectLater(
          c.get('/x'),
          throwsA(isA<ApiException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.code, 'code', 'NETWORK')
              .having(
                  (e) => e.message, 'message', 'Tidak ada koneksi internet.')));
    });
  }

  test('timeout maps to TIMEOUT', () async {
    final c = _make((r) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _json(200, {'data': null});
    }, timeout: const Duration(milliseconds: 50));
    await expectLater(
        c.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 0)
            .having((e) => e.code, 'code', 'TIMEOUT')
            .having((e) => e.message, 'message', 'Koneksi lambat. Coba lagi.')));
  });

  test('post sends JSON body, content-type and extra headers', () async {
    final c = _make((r) async {
      expect(r.method, 'POST');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(r.headers['Idempotency-Key'], 'k1');
      expect(jsonDecode(r.body), {'a': 1});
      return _json(201, {'data': {'id': 'z'}});
    });
    final res = await c.post('/x', body: {'a': 1}, headers: {'Idempotency-Key': 'k1'});
    expect(res.data['id'], 'z');
  });

  test('non-JSON 500 maps to INTERNAL_ERROR', () async {
    final c = _make((r) async => http.Response('<html>oops</html>', 500));
    await expectLater(
        c.get('/x'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 500)
            .having((e) => e.code, 'code', 'INTERNAL_ERROR')
            .having((e) => e.message, 'message', 'Terjadi kesalahan. Coba lagi.')));
  });

  test('get passes query params', () async {
    final c = _make((r) async {
      expect(r.url.queryParameters, {'page': '2'});
      return _json(200, {'data': []});
    });
    await c.get('/menus', query: {'page': '2'});
  });
}
