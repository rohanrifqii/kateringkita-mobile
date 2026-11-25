// Test repository chat pesanan dengan klien HTTP palsu: path, isi permintaan,
// dan pembacaan jawaban server untuk setiap fungsi.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/order_chat_repository.dart';

http.Response jsonResponse(int status, Object? body) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const chatJson = {
  'available': true,
  'is_open': true,
  'closed_reason': null,
  'unread_count': 1,
  'other_party_last_read_id': 4,
  'reported_by_me': false,
};

Map<String, dynamic> messageJson(int id) => {
  'id': id,
  'sender_role': 'merchant',
  'body': 'Halo',
  'image_url': null,
  'created_at': '2026-11-24T02:00:00.000Z',
};

/// Repository dengan [apiHandler] untuk API aplikasi dan [storageHandler]
/// untuk PUT ke penyimpanan.
OrderChatRepository buildRepository(
  MockClientHandler apiHandler, [
  MockClientHandler? storageHandler,
]) => OrderChatRepository(
  ApiClient(client: MockClient(apiHandler), baseUrl: 'https://x.test/api/v1'),
  uploadClient: storageHandler == null ? null : MockClient(storageHandler),
);

void main() {
  test('fetch mengirim after_id dan membaca pesan + keadaan chat', () async {
    late Uri requested;
    final repository = buildRepository((request) async {
      requested = request.url;
      return jsonResponse(200, {
        'data': {
          'messages': [messageJson(5), messageJson(6)],
          'chat': chatJson,
        },
      });
    });
    final result = await repository.fetch('KK-1', afterId: 4);
    expect(requested.path, '/api/v1/orders/KK-1/messages');
    expect(requested.queryParameters, {'after_id': '4'});
    expect(result.messages.map((message) => message.id), [5, 6]);
    expect(result.chat.otherPartyLastReadId, 4);

    await repository.fetch('KK-1');
    expect(requested.queryParameters, isEmpty);
  });

  test('send hanya mengirim kunci yang terisi', () async {
    final bodies = <Map<String, dynamic>>[];
    final repository = buildRepository((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return jsonResponse(201, {'data': messageJson(7)});
    });
    final sent = await repository.send('KK-1', body: '  Halo  ');
    await repository.send('KK-1', imageUrl: 'https://img/x.jpg');
    expect(sent.id, 7);
    expect(bodies, [
      {'body': 'Halo'},
      {'image_url': 'https://img/x.jpg'},
    ]);
  });

  test('markRead mengirim last_id; report mengirim alasan', () async {
    final calls = <String>[];
    final repository = buildRepository((request) async {
      calls.add('${request.url.path} ${request.body}');
      return jsonResponse(request.url.path.endsWith('read') ? 204 : 201, null);
    });
    await repository.markRead('KK-1', lastId: 9);
    await repository.report('KK-1', '  Penjual kasar  ');
    expect(calls, [
      '/api/v1/orders/KK-1/messages/read {"last_id":9}',
      '/api/v1/orders/KK-1/chat-report {"reason":"Penjual kasar"}',
    ]);
  });

  test(
    'uploadImage: minta alamat, PUT dengan Content-Type, kembalikan public_url',
    () async {
      late Map<String, dynamic> uploadRequest;
      late http.Request storageRequest;
      final repository = buildRepository(
        (request) async {
          uploadRequest = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/api/v1/orders/KK-1/messages/upload');
          return jsonResponse(200, {
            'data': {
              'upload_url': 'https://storage.test/put?sig=1',
              'public_url': 'https://img.edufin.app/orders/5/chat/a.png',
              'expires_at': '2026-11-24T03:00:00.000Z',
            },
          });
        },
        (request) async {
          storageRequest = request;
          return http.Response('', 200);
        },
      );
      final publicUrl = await repository.uploadImage(
        'KK-1',
        fileName: 'foto.PNG',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(uploadRequest, {'content_type': 'image/png', 'size': 3});
      expect(storageRequest.method, 'PUT');
      expect(storageRequest.headers['Content-Type'], 'image/png');
      expect(publicUrl, 'https://img.edufin.app/orders/5/chat/a.png');
    },
  );

  test(
    'uploadImage menolak format selain JPG/PNG/WebP tanpa jaringan',
    () async {
      var apiCalls = 0;
      final repository = buildRepository((request) async {
        apiCalls++;
        return jsonResponse(200, {});
      });
      await expectLater(
        repository.uploadImage('KK-1', fileName: 'a.gif', bytes: Uint8List(1)),
        throwsA(isA<ApiException>()),
      );
      expect(apiCalls, 0);
    },
  );

  test(
    'uploadImage memakai mimeType pemilih untuk berkas tanpa ekstensi',
    () async {
      late Map<String, dynamic> uploadRequest;
      final repository = buildRepository(
        (request) async {
          uploadRequest = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse(200, {
            'data': {
              'upload_url': 'https://storage.test/put?sig=1',
              'public_url': 'https://img.edufin.app/orders/5/chat/b.webp',
              'expires_at': '2026-11-24T03:00:00.000Z',
            },
          });
        },
        (request) async => http.Response('', 200),
      );
      await repository.uploadImage(
        'KK-1',
        fileName: 'blob-1234',
        mimeType: 'image/webp',
        bytes: Uint8List.fromList([1]),
      );
      expect(uploadRequest, {'content_type': 'image/webp', 'size': 1});
      // Tipe dari pemilih yang tidak didukung tetap ditolak.
      await expectLater(
        repository.uploadImage(
          'KK-1',
          fileName: 'blob-1234',
          mimeType: 'image/gif',
          bytes: Uint8List(1),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('unreadTotal membaca total dari /me/chats/unread', () async {
    final repository = buildRepository((request) async {
      expect(request.url.path, '/api/v1/me/chats/unread');
      return jsonResponse(200, {
        'data': {'total': 3},
      });
    });
    expect(await repository.unreadTotal(), 3);
  });
}
