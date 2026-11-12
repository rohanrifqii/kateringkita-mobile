import '../api/api_client.dart';
import '../models/app_notification.dart';

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

  Future<NotificationPage> list({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final res = await _api.get('/me/notifications', query: {
      'page': '$page',
      'limit': '$limit',
      if (unreadOnly) 'unread': 'true',
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

  /// Hanya jumlah belum dibaca (untuk lencana lonceng).
  Future<int> unreadCount() async =>
      (await list(limit: 1, unreadOnly: true)).unreadCount;

  /// Tandai [ids] (1–100) sudah dibaca. Mengembalikan sisa belum dibaca.
  Future<int> markRead(List<int> ids) =>
      _read({'ids': ids});

  /// Tandai semua sudah dibaca. Backend mewajibkan `all: true`
  /// (body kosong ditolak 400).
  Future<int> markAllRead() => _read({'all': true});

  Future<int> _read(Map<String, Object> body) async {
    final res = await _api.post('/me/notifications/read', body: body);
    final d = res.data;
    return d is Map ? ((d['unread_count'] as num?)?.toInt() ?? 0) : 0;
  }
}
