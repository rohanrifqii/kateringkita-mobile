// Repository tiket Bantuan & Tiket: layar daftar/buat/detail tiket dan TicketUnreadProvider
// memanggil kelas ini, yang meneruskan ke backend lewat ApiClient (endpoint /me/tickets).
import '../api/api_client.dart';
import '../models/support_ticket.dart';

/// Tiket Bantuan pembeli lewat REST backend (butuh sesi pembeli).
///
/// Galat server diteruskan sebagai `ApiException` (pesan `error.message`,
/// galat per kolom `fields.category|subject|message|order_code|body`), mis.
/// 409 `TOO_MANY_OPEN_TICKETS` saat membuat dan 409 `TICKET_CLOSED` saat
/// membalas tiket yang sudah ditutup.
class TicketRepository {
  TicketRepository(this._api);

  final ApiClient _api;

  static const _base = '/me/tickets';

  /// Path satu tiket; kode di-encode agar aman dipakai di URL.
  String _path(String code) => '$_base/${Uri.encodeComponent(code)}';

  TicketDetail _detail(ApiResponse res) =>
      TicketDetail.fromJson(res.data as Map<String, dynamic>);

  /// Satu halaman tiket milik pembeli (`GET /me/tickets?page=&limit=`), terbaru
  /// (`last_message_at`) dulu. [limit] maks 50 di server. Bila `meta` tidak
  /// ada, total dan jumlah belum dibaca dihitung dari item halaman ini.
  Future<TicketPage> list({int page = 1, int limit = 20}) async {
    final res = await _api.get(_base, query: {
      'page': '$page',
      'limit': '$limit',
    });
    final items = (res.data as List)
        .map((e) => TicketSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = res.meta;
    return TicketPage(
      items: items,
      total: (meta?['total'] as num?)?.toInt() ?? items.length,
      page: (meta?['page'] as num?)?.toInt() ?? page,
      unreadCount: (meta?['unread_count'] as num?)?.toInt() ??
          items.where((t) => t.unread).length,
    );
  }

  /// Hanya jumlah tiket berbalasan belum dibaca (titik di menu Profil);
  /// memanggil [list] dengan `limit: 1` lalu membaca `meta.unread_count`.
  Future<int> unreadCount() async => (await list(limit: 1)).unreadCount;

  /// Membuat tiket baru (`POST /me/tickets`, balasan 201 → detail tiket baru).
  /// Teks di-trim dulu; [orderCode] kosong tidak dikirim.
  Future<TicketDetail> create({
    required String category,
    required String subject,
    required String message,
    String? orderCode,
  }) async {
    final order = orderCode?.trim();
    return _detail(await _api.post(_base, body: {
      'category': category,
      'subject': subject.trim(),
      'message': message.trim(),
      if (order != null && order.isNotEmpty) 'order_code': order,
    }));
  }

  /// Detail tiket + seluruh pesannya (`GET /me/tickets/:code`). Sekaligus
  /// menandai balasan admin sudah dibaca di server.
  Future<TicketDetail> get(String code) async =>
      _detail(await _api.get(_path(code)));

  /// Mengirim balasan pembeli (`POST /me/tickets/:code/messages`, teks di-trim)
  /// dan mengembalikan detail tiket terbaru. 409 `TICKET_CLOSED` bila tiket sudah ditutup.
  Future<TicketDetail> reply(String code, String body) async => _detail(
      await _api.post('${_path(code)}/messages', body: {'body': body.trim()}));

  /// Menutup tiket (`POST /me/tickets/:code/close`) dan mengembalikan detailnya.
  /// Tiket yang sudah ditutup dikembalikan apa adanya (200).
  Future<TicketDetail> close(String code) async =>
      _detail(await _api.post('${_path(code)}/close'));
}
