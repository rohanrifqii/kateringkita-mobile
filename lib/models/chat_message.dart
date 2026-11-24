// Model chat satu pesanan antara pembeli dan penjual: satu pesan, keadaan chat
// untuk pembeli, dan fungsi untuk menggabungkan pesan hasil cek berkala.
// Dibuat dari JSON oleh OrderChatRepository dan ditampilkan di layar Chat pesanan.

/// Satu pesan chat pesanan (teks, foto, atau keduanya).
class ChatMessage {
  /// Id pesan dari server; naik terus, jadi juga dipakai untuk urutan.
  final int id;

  /// Pengirim: `customer` (pembeli) atau `merchant` (penjual).
  final String senderRole;

  /// Isi teks, atau null bila pesan hanya berisi foto.
  final String? body;

  /// Alamat foto, atau null bila pesan hanya berisi teks.
  final String? imageUrl;

  /// Waktu pesan dikirim (UTC).
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderRole,
    this.body,
    this.imageUrl,
    required this.createdAt,
  });

  /// True bila pesan ini dikirim pembeli, yaitu pengguna aplikasi ini.
  bool get isFromCustomer => senderRole == 'customer';

  /// Membaca satu pesan dari JSON server.
  ///
  /// @param json objek `{id, sender_role, body, image_url, created_at}`.
  /// @returns pesan yang siap ditampilkan.
  /// @throws TypeError bila kunci wajib hilang atau bertipe salah.
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num).toInt(),
    senderRole: json['sender_role'] as String,
    body: json['body'] as String?,
    imageUrl: json['image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Keadaan chat sebuah pesanan dilihat dari sisi pembeli.
class ChatState {
  /// False untuk pesanan tamu QR meja, yang tidak punya chat.
  final bool available;

  /// True hanya saat pesanan `confirmed`, `cooking`, atau `ready`.
  final bool isOpen;

  /// Alasan chat tertutup: `not_started`, `finished`, `unavailable`, atau null
  /// bila chat terbuka.
  final String? closedReason;

  /// Jumlah pesan penjual yang belum dibaca pembeli.
  final int unreadCount;

  /// Id pesan terakhir yang sudah dibaca penjual, untuk tanda "Dibaca".
  final int? otherPartyLastReadId;

  /// True bila pembeli sudah pernah melaporkan chat ini.
  final bool reportedByMe;

  const ChatState({
    required this.available,
    required this.isOpen,
    this.closedReason,
    this.unreadCount = 0,
    this.otherPartyLastReadId,
    this.reportedByMe = false,
  });

  /// Membaca keadaan chat dari JSON server.
  ///
  /// @param json objek `chat` dari server: `{available, is_open,
  ///   closed_reason, unread_count, other_party_last_read_id, reported_by_me}`.
  /// @returns keadaan chat; angka yang hilang dianggap 0.
  /// @throws TypeError bila `available` atau `is_open` bukan boolean.
  factory ChatState.fromJson(Map<String, dynamic> json) => ChatState(
    available: json['available'] as bool,
    isOpen: json['is_open'] as bool,
    closedReason: json['closed_reason'] as String?,
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    otherPartyLastReadId: (json['other_party_last_read_id'] as num?)?.toInt(),
    reportedByMe: (json['reported_by_me'] as bool?) ?? false,
  );

  /// Salinan dengan beberapa nilai diganti; nilai lain tetap.
  ///
  /// `available` dan `otherPartyLastReadId` selalu disalin apa adanya.
  ///
  /// @param isOpen apakah chat masih menerima pesan baru.
  /// @param closedReason alasan tertutup (`not_started`, `finished`,
  ///   `unavailable`); null berarti alasan lama dipertahankan.
  /// @param unreadCount jumlah pesan penjual yang belum dibaca, mis. 0
  ///   sesudah ditandai dibaca.
  /// @param reportedByMe true sesudah pembeli melaporkan chat ini.
  /// @returns keadaan chat baru; objek lama tidak berubah.
  ChatState copyWith({
    bool? isOpen,
    String? closedReason,
    int? unreadCount,
    bool? reportedByMe,
  }) => ChatState(
    available: available,
    isOpen: isOpen ?? this.isOpen,
    closedReason: closedReason ?? this.closedReason,
    unreadCount: unreadCount ?? this.unreadCount,
    otherPartyLastReadId: otherPartyLastReadId,
    reportedByMe: reportedByMe ?? this.reportedByMe,
  );
}

/// Menggabungkan pesan yang sudah tampil dengan pesan baru dari server.
///
/// Pesan dengan id yang sama hanya disimpan sekali (versi terbaru menang), lalu
/// hasilnya diurutkan menurut id naik. Dengan begitu cek berkala yang tumpang
/// tindih dengan pengiriman pesan tidak pernah menampilkan pesan ganda.
///
/// @param existing pesan yang sudah ditampilkan.
/// @param incoming pesan baru dari cek berkala atau dari pengiriman.
/// @returns daftar baru tanpa duplikat, urut id naik.
List<ChatMessage> mergeMessages(
  List<ChatMessage> existing,
  List<ChatMessage> incoming,
) {
  final messagesById = {
    for (final message in [...existing, ...incoming]) message.id: message,
  };
  return messagesById.values.toList()
    ..sort((first, second) => first.id.compareTo(second.id));
}
