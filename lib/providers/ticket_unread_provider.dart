import 'package:flutter/foundation.dart';

import '../data/ticket_repository.dart';

/// Jumlah tiket Bantuan yang punya balasan admin belum dibaca (titik di
/// menu Profil "Bantuan & Tiket"). Dikosongkan saat keluar.
class TicketUnreadProvider extends ChangeNotifier {
  TicketUnreadProvider(this._repo);

  final TicketRepository _repo;

  int _unread = 0;
  int get unreadCount => _unread;

  bool _fetching = false;

  /// Naik saat [clear]; jawaban dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  /// Galat diabaikan: titik bukan informasi penting.
  Future<void> refresh() async {
    if (_fetching) return;
    final epoch = _epoch;
    _fetching = true;
    try {
      final n = await _repo.unreadCount();
      if (epoch == _epoch) setUnread(n);
    } catch (_) {
      // Coba lagi saat Profil dibuka berikutnya.
    } finally {
      if (epoch == _epoch) _fetching = false;
    }
  }

  /// Dipakai saat server sudah mengembalikan `meta.unread_count`.
  void setUnread(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _unread) return;
    _unread = v;
    notifyListeners();
  }

  void clear() {
    _epoch++;
    _fetching = false;
    setUnread(0);
  }
}
