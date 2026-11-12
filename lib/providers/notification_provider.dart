import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';

/// Jumlah notifikasi belum dibaca (lencana lonceng beranda), dibagi antara
/// beranda dan layar Notifikasi.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._repo);

  final NotificationRepository _repo;

  int _unread = 0;
  int get unreadCount => _unread;

  bool _fetching = false;

  /// Naik saat [clear]; jawaban dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  /// Ambil ulang jumlah belum dibaca. Galat diabaikan (lencana tetap).
  Future<void> refresh() async {
    if (_fetching) return;
    final epoch = _epoch;
    _fetching = true;
    try {
      final n = await _repo.unreadCount();
      if (epoch == _epoch) setUnread(n);
    } catch (_) {
      // Lencana bukan informasi penting; coba lagi pada jadwal berikutnya.
    } finally {
      if (epoch == _epoch) _fetching = false;
    }
  }

  /// Dipakai saat server sudah mengembalikan `unread_count` (daftar/tandai).
  void setUnread(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _unread) return;
    _unread = v;
    notifyListeners();
  }

  /// Keluar / sesi tidak valid.
  void clear() {
    _epoch++;
    _fetching = false;
    setUnread(0);
  }
}
