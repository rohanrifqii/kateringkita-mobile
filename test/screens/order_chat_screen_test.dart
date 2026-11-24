// Widget test halaman Chat pesanan dengan repository palsu: pesan cepat, cek
// berkala tiap 5 detik dengan after_id, jeda di latar belakang, beralih ke
// hanya-baca saat chat ditutup, validasi laporan, dan tanda "Dibaca".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/order_chat_repository.dart';
import 'package:kateringkita_pbl/models/chat_message.dart';
import 'package:kateringkita_pbl/screens/orders/order_chat_screen.dart';
import 'package:provider/provider.dart';

/// Pesan palsu dengan [id] dari [senderRole].
ChatMessage chatMessage(int id, String senderRole, String body) => ChatMessage(
  id: id,
  senderRole: senderRole,
  body: body,
  createdAt: DateTime.utc(2026, 11, 24, 2, id),
);

/// Keadaan chat terbuka dengan [otherPartyLastReadId] dan [unreadCount].
ChatState openChat({int? otherPartyLastReadId, int unreadCount = 0}) =>
    ChatState(
      available: true,
      isOpen: true,
      unreadCount: unreadCount,
      otherPartyLastReadId: otherPartyLastReadId,
    );

/// Repository palsu: fetch pertama mengembalikan [initialMessages], fetch
/// berikutnya mengembalikan [messagesAfter] untuk `afterId` itu (kosong bila
/// tidak ada). Semua panggilan dicatat untuk diperiksa test.
class FakeOrderChatRepository implements OrderChatRepository {
  FakeOrderChatRepository({
    this.initialMessages = const [],
    ChatState? chat,
    this.sendError,
    this.messagesAfter = const {},
    this.nextSentId = 100,
  }) : chat = chat ?? openChat();

  final List<ChatMessage> initialMessages;
  ChatState chat;
  ApiException? sendError;
  final Map<int, List<ChatMessage>> messagesAfter;
  int nextSentId;

  final List<int?> fetchAfterIds = [];
  final List<String?> sentBodies = [];
  final List<int?> markReadLastIds = [];
  final List<String> reportReasons = [];

  @override
  Future<({List<ChatMessage> messages, ChatState chat})> fetch(
    String code, {
    int? afterId,
  }) async {
    fetchAfterIds.add(afterId);
    return (
      messages: afterId == null
          ? initialMessages
          : messagesAfter[afterId] ?? <ChatMessage>[],
      chat: chat,
    );
  }

  @override
  Future<ChatMessage> send(
    String code, {
    String? body,
    String? imageUrl,
  }) async {
    final error = sendError;
    if (error != null) throw error;
    sentBodies.add(body);
    return chatMessage(nextSentId++, 'customer', body ?? '');
  }

  @override
  Future<void> markRead(String code, {int? lastId}) async =>
      markReadLastIds.add(lastId);

  @override
  Future<void> report(String code, String reason) async =>
      reportReasons.add(reason);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Memasang halaman Chat untuk pesanan "KK-1" dengan [repository].
Future<void> pumpChatScreen(
  WidgetTester tester,
  FakeOrderChatRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<OrderChatRepository>.value(
      value: repository,
      child: const MaterialApp(home: OrderChatScreen(orderCode: 'KK-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pesan cepat "Saya sudah di titik temu" mengirim teks itu', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository();
    await pumpChatScreen(tester, repository);

    await tester.tap(find.text('Saya sudah di titik temu'));
    await tester.pumpAndSettle();
    expect(repository.sentBodies, ['Saya sudah di titik temu']);
    expect(find.text('Saya sudah di titik temu'), findsNWidgets(2));
  });

  testWidgets('setelah 5 detik fetch dipanggil dengan afterId id terakhir', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository(
      initialMessages: [
        chatMessage(1, 'customer', 'Halo'),
        chatMessage(2, 'merchant', 'Siap'),
      ],
    );
    await pumpChatScreen(tester, repository);
    expect(repository.fetchAfterIds, [null]);

    await tester.pump(const Duration(seconds: 5));
    expect(repository.fetchAfterIds, [null, 2]);
  });

  testWidgets(
    'pesan penjual belum dibaca: ditandai dibaca sampai id terakhir',
    (tester) async {
      final repository = FakeOrderChatRepository(
        initialMessages: [
          chatMessage(1, 'customer', 'Halo'),
          chatMessage(2, 'merchant', 'Siap'),
        ],
        chat: openChat(unreadCount: 1),
      );
      await pumpChatScreen(tester, repository);
      expect(repository.markReadLastIds, [2]);
    },
  );

  testWidgets('paused menghentikan cek berkala, resumed langsung cek lagi', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository();
    await pumpChatScreen(tester, repository);
    expect(repository.fetchAfterIds.length, 1);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 20));
    expect(repository.fetchAfterIds.length, 1);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(repository.fetchAfterIds.length, 2);
  });

  testWidgets('409 CHAT_CLOSED saat mengirim: halaman jadi hanya-baca', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository(
      sendError: const ApiException(
        status: 409,
        code: 'CHAT_CLOSED',
        message: 'Chat sudah ditutup karena pesanan selesai atau dibatalkan.',
      ),
    );
    await pumpChatScreen(tester, repository);

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Halo');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    expect(
      find.text('Chat sudah ditutup karena pesanan selesai atau dibatalkan.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-input')), findsNothing);
    expect(find.text('Saya sudah di titik temu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laporan dengan alasan kurang dari 5 karakter tidak terkirim', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository();
    await pumpChatScreen(tester, repository);

    await tester.tap(find.text('Laporkan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-report-reason')),
      'abc',
    );
    await tester.tap(find.text('Kirim laporan'));
    await tester.pumpAndSettle();

    expect(repository.reportReasons, isEmpty);
    expect(find.text('Alasan 5–500 karakter.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-report-reason')),
      'Penjual berkata kasar',
    );
    await tester.tap(find.text('Kirim laporan'));
    await tester.pumpAndSettle();
    expect(repository.reportReasons, ['Penjual berkata kasar']);
  });

  testWidgets('tanda "Dibaca" muncul pada pesan terakhir pembeli', (
    tester,
  ) async {
    final repository = FakeOrderChatRepository(
      initialMessages: [
        chatMessage(1, 'customer', 'Halo'),
        chatMessage(2, 'customer', 'Saya di gerbang'),
        chatMessage(3, 'merchant', 'Oke'),
      ],
      chat: openChat(otherPartyLastReadId: 2),
    );
    await pumpChatScreen(tester, repository);

    expect(find.text('Dibaca'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chat-message-2')),
        matching: find.text('Dibaca'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'pesan penjual yang datang saat pembeli mengirim tidak terlewat',
    (tester) async {
      // Layar memuat [1, 2]; penjual mengirim 3; kiriman pembeli dijawab id 4.
      final repository = FakeOrderChatRepository(
        initialMessages: [
          chatMessage(1, 'customer', 'Halo'),
          chatMessage(2, 'merchant', 'Siap'),
        ],
        chat: openChat(unreadCount: 1),
        nextSentId: 4,
        messagesAfter: {
          2: [
            chatMessage(3, 'merchant', 'Saya di dekat gerbang'),
            chatMessage(4, 'customer', 'Saya sudah di titik temu'),
          ],
        },
      );
      await pumpChatScreen(tester, repository);
      expect(repository.markReadLastIds, [2]);

      await tester.tap(find.text('Saya sudah di titik temu'));
      await tester.pumpAndSettle();
      // Sebelum pesan 3 tampil, tanda baca tidak boleh melewati id 2.
      expect(repository.markReadLastIds, [2]);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(repository.fetchAfterIds, [null, 2]);
      expect(find.text('Saya di dekat gerbang'), findsOneWidget);
      expect(find.text('Saya sudah di titik temu'), findsNWidgets(2));
      expect(repository.markReadLastIds, [2, 4]);
    },
  );
}
