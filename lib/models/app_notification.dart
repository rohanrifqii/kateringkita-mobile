// Model notifikasi in-app dari backend (GET /me/notifications), dibaca lewat NotificationRepository
// dan ditampilkan di layar Notifikasi.
import 'dart:convert';

/// Notifikasi in-app dari `GET /me/notifications`.
///
/// `type` dari backend: `order_status` (data `{order_code, status}`),
/// `promo` (promo toko yang menunya difavoritkan) dan `info` (pengumuman;
/// balasan/penutupan tiket Bantuan membawa `data {ticket_code}`).
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  /// Data tambahan sesuai [type], mis. `{order_code, status}` untuk `order_status`.
  final Map<String, dynamic> data;

  /// Waktu dibaca; null berarti belum dibaca.
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  /// True bila sudah dibaca ([readAt] terisi).
  bool get isRead => readAt != null;

  /// True untuk notifikasi perubahan status pesanan.
  bool get isOrderStatus => type == 'order_status';

  /// Kode pesanan dari [data]; null bila bukan notifikasi pesanan.
  String? get orderCode => data['order_code'] as String?;

  /// Status pesanan dari [data]; null bila bukan notifikasi pesanan.
  String? get orderStatus => data['status'] as String?;

  /// Kode tiket Bantuan (notifikasi balasan / tiket ditutup), atau null.
  String? get ticketCode {
    final v = data['ticket_code'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// Salinan notifikasi yang ditandai dibaca pada [at]; [readAt] lama dipertahankan
  /// bila sudah dibaca sebelumnya.
  AppNotification markedRead(DateTime at) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        readAt: readAt ?? at,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        type: (json['type'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        data: _data(json['data']),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Kolom JSON bisa datang sebagai objek atau string (tergantung driver).
  static Map<String, dynamic> _data(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return const {};
  }
}
