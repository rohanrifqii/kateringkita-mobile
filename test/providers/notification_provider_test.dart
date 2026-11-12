import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';
import 'package:kateringkita_pbl/providers/notification_provider.dart';

http.Response _meta(int unread) => http.Response(
    jsonEncode({
      'data': [],
      'meta': {'page': 1, 'limit': 1, 'total': unread, 'unread_count': unread}
    }),
    200,
    headers: {'content-type': 'application/json'});

NotificationProvider _provider(MockClientHandler h) => NotificationProvider(
    NotificationRepository(
        ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1')));

void main() {
  test('refresh mengisi unreadCount dan memberi tahu pendengar', () async {
    final p = _provider((req) async => _meta(3));
    var notified = 0;
    p.addListener(() => notified++);
    await p.refresh();
    expect(p.unreadCount, 3);
    expect(notified, 1);
  });

  test('refresh gagal: angka lama dipertahankan, tanpa lempar galat',
      () async {
    var fail = false;
    final p = _provider((req) async {
      if (fail) throw const _Boom();
      return _meta(2);
    });
    await p.refresh();
    fail = true;
    await p.refresh();
    expect(p.unreadCount, 2);
  });

  test('refresh bersamaan hanya satu permintaan', () async {
    var calls = 0;
    final gate = Completer<void>();
    final p = _provider((req) async {
      calls++;
      await gate.future;
      return _meta(1);
    });
    final a = p.refresh();
    final b = p.refresh();
    gate.complete();
    await Future.wait([a, b]);
    expect(calls, 1);
  });

  test('clear: angka nol dan jawaban sesi lama diabaikan', () async {
    final gate = Completer<void>();
    final p = _provider((req) async {
      await gate.future;
      return _meta(9);
    });
    p.setUnread(4);
    final f = p.refresh();
    p.clear();
    expect(p.unreadCount, 0);
    gate.complete();
    await f;
    expect(p.unreadCount, 0);
  });

  test('setUnread tidak pernah negatif', () {
    final p = _provider((req) async => _meta(0));
    p.setUnread(-1);
    expect(p.unreadCount, 0);
  });
}

/// Galat apa pun dari jaringan/klien.
class _Boom implements Exception {
  const _Boom();
}
