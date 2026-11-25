// Model tiket Bantuan dari backend (/me/tickets), dibuat oleh TicketRepository dan ditampilkan di
// layar daftar, buat, dan detail tiket. Juga berisi aturan validasi form tiket.

/// Tiket Bantuan dua arah (pembeli ↔ Tim KateringKita) dari
/// `/me/tickets`. Urusan pesanan (menu, waktu ambil, pesanan belum siap)
/// tetap ke penjual lewat WhatsApp di Pesanan.
library;

/// Kategori di server → label tampilan (urutan = urutan chip).
const Map<String, String> ticketCategories = {
  'akun': 'Akun',
  'pembayaran': 'Pembayaran',
  'pesanan': 'Pesanan',
  'penjual': 'Penjual',
  'aplikasi': 'Aplikasi',
  'lainnya': 'Lainnya',
};

/// Label tampilan untuk kode kategori; kode tak dikenal → "Lainnya".
String ticketCategoryLabel(String category) =>
    ticketCategories[category] ?? 'Lainnya';

/// Label tampilan status tiket: `open` menunggu admin, `answered` admin sudah
/// membalas, `closed` selesai. Status lain ditampilkan apa adanya.
String ticketStatusLabel(String status) => switch (status) {
      'open' => 'Menunggu admin',
      'answered' => 'Dibalas',
      'closed' => 'Ditutup',
      _ => status,
    };

/// Nama yang selalu dikirim server untuk balasan admin.
const String kTicketAdminName = 'Tim KateringKita';

/// Validasi klien, identik dengan server (panjang dihitung setelah trim).
/// Setiap fungsi mengembalikan pesan galat, atau null bila valid.
class TicketRules {
  TicketRules._();

  static const int subjectMin = 3;
  static const int subjectMax = 120;
  static const int messageMin = 5;
  static const int messageMax = 2000;
  static const int replyMin = 1;
  static const int replyMax = 2000;

  /// Kategori harus salah satu kunci [ticketCategories].
  static String? category(String? value) =>
      ticketCategories.containsKey(value) ? null : 'Pilih kategori.';

  /// Judul tiket: 3–120 karakter.
  static String? subject(String value) =>
      _len(value, subjectMin, subjectMax) ? null : 'Judul 3–120 karakter.';

  /// Pesan pertama saat membuat tiket: 5–2000 karakter.
  static String? message(String value) =>
      _len(value, messageMin, messageMax) ? null : 'Pesan 5–2000 karakter.';

  /// Balasan di detail tiket: 1–2000 karakter.
  static String? reply(String value) =>
      _len(value, replyMin, replyMax) ? null : 'Pesan 1–2000 karakter.';

  static bool _len(String value, int min, int max) {
    final n = value.trim().length;
    return n >= min && n <= max;
  }
}

// Pembantu parsing JSON: tanggal opsional dan string kosong → null.
DateTime? _dt(Object? v) => v is String ? DateTime.parse(v) : null;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// Bagian bersama TicketSummary & TicketDetail.
abstract class _TicketBase {
  String get code;
  String get category;
  String get status;

  String get categoryLabel => ticketCategoryLabel(category);
  String get statusLabel => ticketStatusLabel(status);
  bool get isClosed => status == 'closed';
}

/// Item daftar `GET /me/tickets`.
class TicketSummary extends _TicketBase {
  @override
  final String code;
  @override
  final String category;
  final String subject;
  @override
  final String status;
  final String? orderCode;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessagePreview;

  /// `customer` | `admin`.
  final String? lastSenderRole;

  /// Ada balasan admin yang belum dibaca pembeli.
  final bool unread;

  TicketSummary({
    required this.code,
    required this.category,
    required this.subject,
    required this.status,
    this.orderCode,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview = '',
    this.lastSenderRole,
    this.unread = false,
  });

  factory TicketSummary.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['created_at'] as String);
    return TicketSummary(
      code: json['code'] as String,
      category: (json['category'] as String?) ?? 'lainnya',
      subject: (json['subject'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      orderCode: _str(json['order_code']),
      createdAt: created,
      lastMessageAt: _dt(json['last_message_at']) ?? created,
      lastMessagePreview: (json['last_message_preview'] as String?) ?? '',
      lastSenderRole: _str(json['last_sender_role']),
      unread: json['unread'] == true,
    );
  }
}

/// Satu pesan dalam percakapan tiket (dari pembeli atau admin).
class TicketMessage {
  final int id;

  /// `customer` | `admin`.
  final String senderRole;

  /// Untuk admin selalu "Tim KateringKita"; pesan pembeli: null.
  final String? senderName;
  final String body;
  final DateTime createdAt;

  const TicketMessage({
    required this.id,
    required this.senderRole,
    this.senderName,
    required this.body,
    required this.createdAt,
  });

  /// True bila pesan dikirim admin (Tim KateringKita).
  bool get fromAdmin => senderRole == 'admin';

  /// Nama pengirim untuk ditampilkan: nama dari server, atau "Tim KateringKita"
  /// (admin) / "Kamu" (pembeli) bila kosong.
  String get displayName =>
      fromAdmin ? (senderName ?? kTicketAdminName) : (senderName ?? 'Kamu');

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
        id: (json['id'] as num).toInt(),
        senderRole: (json['sender_role'] as String?) ?? 'customer',
        senderName: _str(json['sender_name']),
        body: (json['body'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// `GET /me/tickets/:code` (juga hasil buat, balas, tutup).
class TicketDetail extends _TicketBase {
  @override
  final String code;
  @override
  final String category;
  final String subject;
  @override
  final String status;
  final String? orderCode;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? lastSenderRole;
  final DateTime? closedAt;

  /// `customer` | `admin`.
  final String? closedBy;
  final List<TicketMessage> messages;

  TicketDetail({
    required this.code,
    required this.category,
    required this.subject,
    required this.status,
    this.orderCode,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastSenderRole,
    this.closedAt,
    this.closedBy,
    this.messages = const [],
  });

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['created_at'] as String);
    return TicketDetail(
      code: json['code'] as String,
      category: (json['category'] as String?) ?? 'lainnya',
      subject: (json['subject'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      orderCode: _str(json['order_code']),
      createdAt: created,
      lastMessageAt: _dt(json['last_message_at']) ?? created,
      lastSenderRole: _str(json['last_sender_role']),
      closedAt: _dt(json['closed_at']),
      closedBy: _str(json['closed_by']),
      messages: ((json['messages'] as List?) ?? const [])
          .map((e) => TicketMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu halaman hasil `GET /me/tickets` beserta info `meta` (total, halaman,
/// jumlah belum dibaca).
class TicketPage {
  final List<TicketSummary> items;
  final int total;
  final int page;

  /// Jumlah tiket milik akun yang punya balasan belum dibaca (global,
  /// tidak terpengaruh halaman).
  final int unreadCount;

  const TicketPage({
    required this.items,
    required this.total,
    required this.page,
    required this.unreadCount,
  });
}
