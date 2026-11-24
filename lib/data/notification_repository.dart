// Repository notifikasi in-app: daftar notifikasi dan tandai sudah dibaca.
// Alur: layar Notifikasi / NotificationProvider → NotificationRepository → ApiClient → backend (/me/notifications).
import '../api/api_client.dart';
import '../models/app_notification.dart';

/// Satu halaman hasil [NotificationRepository.list]: [items], [total] sesuai
/// filter, [page] mulai 1, dan [unreadCount].
class NotificationPage {
  final List<AppNotification> items;
  final int total;
  final int page;

  /// Semua yang belum dibaca milik akun, tidak terpengaruh filter/halaman.
  final int unreadCount;

  const NotificationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.unreadCount,
  });
}

/// Notifikasi in-app lewat REST backend (butuh sesi).
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  /// GET /me/notifications: satu halaman notifikasi, terbaru menurut server.
  /// [unreadOnly] hanya yang belum dibaca.
  /// [type]: `order_status` | `promo` | `info` (filter di server; tipe lain
  /// ditolak 400). `total` mengikuti filter, `unreadCount` tidak.
  Future<NotificationPage> list({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
    String? type,
  }) async {
    final res = await _api.get('/me/notifications', query: {
      'page': '$page',
      'limit': '$limit',
      if (unreadOnly) 'unread': 'true',
      'type': ?type,
    });
    final items = (res.data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = res.meta;
    return NotificationPage(
      items: items,
      total: (meta?['total'] as num?)?.toInt() ?? items.length,
      page: (meta?['page'] as num?)?.toInt() ?? page,
      unreadCount: (meta?['unread_count'] as num?)?.toInt() ??
          items.where((n) => !n.isRead).length,
    );
  }

  /// Hanya jumlah belum dibaca (untuk lencana lonceng); meminta 1 item saja
  /// lalu membaca `unread_count` dari meta.
  Future<int> unreadCount() async =>
      (await list(limit: 1, unreadOnly: true)).unreadCount;

  /// POST /me/notifications/read `{ids}`: tandai [ids] (1–100) sudah dibaca.
  /// Mengembalikan sisa belum dibaca.
  Future<int> markRead(List<int> ids) =>
      _read({'ids': ids});

  /// POST /me/notifications/read `{all: true}`: tandai semua sudah dibaca dan
  /// kembalikan sisa belum dibaca. Backend mewajibkan `all: true`
  /// (body kosong ditolak 400).
  Future<int> markAllRead() => _read({'all': true});

  /// Kirim permintaan tandai-dibaca; balasan tanpa unread_count dianggap 0.
  Future<int> _read(Map<String, Object> body) async {
    final res = await _api.post('/me/notifications/read', body: body);
    final d = res.data;
    return d is Map ? ((d['unread_count'] as num?)?.toInt() ?? 0) : 0;
  }
}
