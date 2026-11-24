import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/ticket_repository.dart';
import 'package:kateringkita_pbl/providers/ticket_unread_provider.dart';

http.Response _meta(int unread) => http.Response(
    jsonEncode({
      'data': [],
      'meta': {'page': 1, 'limit': 1, 'total': 0, 'unread_count': unread}
    }),
    200,
    headers: {'content-type': 'application/json'});

TicketUnreadProvider _provider(MockClientHandler h) => TicketUnreadProvider(
    TicketRepository(
        ApiClient(client: MockClient(h), baseUrl: 'https://x.test/api/v1')));

void main() {
  test('refresh mengambil meta.unread_count dari /me/tickets', () async {
    late Uri url;
    final p = _provider((req) async {
      url = req.url;
      return _meta(2);
    });
    var notified = 0;
    p.addListener(() => notified++);
    await p.refresh();
    expect(url.path, '/api/v1/me/tickets');
    expect(p.unreadCount, 2);
    expect(notified, 1);
  });

  test('refresh gagal: angka lama dipertahankan', () async {
    var fail = false;
    final p = _provider((req) async {
      if (fail) return http.Response('x', 500);
      return _meta(3);
    });
    await p.refresh();
    fail = true;
    await p.refresh();
    expect(p.unreadCount, 3);
  });

  test('clear: jawaban dari sesi sebelumnya diabaikan', () async {
    final gate = Completer<void>();
    final p = _provider((req) async {
      await gate.future;
      return _meta(5);
    });
    final pending = p.refresh();
    p.clear();
    gate.complete();
    await pending;
    expect(p.unreadCount, 0);
  });

  test('setUnread tidak negatif & tanpa notifikasi bila sama', () {
    final p = _provider((req) async => _meta(0));
    var notified = 0;
    p.addListener(() => notified++);
    p.setUnread(-1);
    expect(p.unreadCount, 0);
    expect(notified, 0);
    p.setUnread(1);
    expect(notified, 1);
  });
}
