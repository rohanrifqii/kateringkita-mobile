// Test model chat pesanan: membaca bentuk JSON bersama dan menggabungkan
// pesan hasil cek berkala tanpa duplikat.
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/chat_message.dart';

/// Pesan dari server dengan [id] dan isi teks [body].
Map<String, dynamic> messageJson(int id, {String? body = 'Halo'}) => {
  'id': id,
  'sender_role': 'customer',
  'body': body,
  'image_url': null,
  'created_at': '2026-11-24T02:00:00.000Z',
};

void main() {
  test('ChatMessage.fromJson membaca semua kunci', () {
    final message = ChatMessage.fromJson({
      'id': 12,
      'sender_role': 'merchant',
      'body': null,
      'image_url': 'https://img.edufin.app/orders/5/chat/a.jpg',
      'created_at': '2026-11-24T02:05:00.000Z',
    });
    expect(message.id, 12);
    expect(message.isFromCustomer, isFalse);
    expect(message.body, isNull);
    expect(message.imageUrl, 'https://img.edufin.app/orders/5/chat/a.jpg');
    expect(message.createdAt, DateTime.utc(2026, 11, 24, 2, 5));
    expect(ChatMessage.fromJson(messageJson(1)).isFromCustomer, isTrue);
  });

  test('ChatState.fromJson membaca semua kunci', () {
    final state = ChatState.fromJson({
      'available': true,
      'is_open': false,
      'closed_reason': 'finished',
      'unread_count': 3,
      'other_party_last_read_id': 9,
      'reported_by_me': true,
    });
    expect(state.available, isTrue);
    expect(state.isOpen, isFalse);
    expect(state.closedReason, 'finished');
    expect(state.unreadCount, 3);
    expect(state.otherPartyLastReadId, 9);
    expect(state.reportedByMe, isTrue);

    final open = ChatState.fromJson({
      'available': true,
      'is_open': true,
      'closed_reason': null,
      'unread_count': 0,
      'other_party_last_read_id': null,
      'reported_by_me': false,
    });
    expect(open.closedReason, isNull);
    expect(open.otherPartyLastReadId, isNull);
  });

  test('mergeMessages tidak menggandakan pesan dan menjaga urutan id', () {
    final existing = [
      1,
      2,
      3,
    ].map((id) => ChatMessage.fromJson(messageJson(id)));
    final incoming = [
      3,
      5,
      4,
    ].map((id) => ChatMessage.fromJson(messageJson(id)));
    final merged = mergeMessages(existing.toList(), incoming.toList());
    expect(merged.map((message) => message.id), [1, 2, 3, 4, 5]);
    expect(mergeMessages(merged, const []).length, 5);
  });
}
