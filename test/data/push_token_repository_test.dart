// Isi file: test PushTokenRepository (daftar/hapus token push perangkat) dengan MockClient.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/push_token_repository.dart';

PushTokenRepository _repo(MockClientHandler h) => PushTokenRepository(
    ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1'));

void main() {
  test('register: PUT /me/push-token dengan body {token, platform}', () async {
    late http.Request captured;
    final r = _repo((req) async {
      captured = req;
      return http.Response('', 204);
    });
    await r.register('t1', 'android');
    expect(captured.method, 'PUT');
    expect(captured.url.toString(), 'https://x.test/api/v1/me/push-token');
    expect(captured.body, '{"token":"t1","platform":"android"}');
  });

  test('unregister: DELETE /me/push-token', () async {
    late http.Request captured;
    final r = _repo((req) async {
      captured = req;
      return http.Response('', 204);
    });
    await r.unregister();
    expect(captured.method, 'DELETE');
    expect(captured.url.toString(), 'https://x.test/api/v1/me/push-token');
  });

  test('galat server diteruskan ke pemanggil', () async {
    final r = _repo((req) async => http.Response('', 500));
    expect(r.register('t1', 'web'), throwsA(isA<ApiException>()));
  });
}
