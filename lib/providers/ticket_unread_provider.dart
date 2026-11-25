// Provider jumlah tiket Bantuan berbalasan admin yang belum dibaca. Dibuat di main.dart, dibaca
// ProfileScreen untuk titik merah; layar tiket memperbaruinya. Data dari TicketRepository.
import 'package:flutter/foundation.dart';

import '../data/ticket_repository.dart';

/// Jumlah tiket Bantuan yang punya balasan admin belum dibaca (titik di
/// menu Profil "Bantuan & Tiket"). Dikosongkan saat keluar.
class TicketUnreadProvider extends ChangeNotifier {
  TicketUnreadProvider(this._repo);

  final TicketRepository _repo;

  int _unread = 0;
  /// Jumlah tiket yang punya balasan admin belum dibaca (tidak pernah negatif).
  int get unreadCount => _unread;

  /// Mencegah dua permintaan [refresh] berjalan bersamaan.
  bool _fetching = false;

  /// Naik saat [clear]; jawaban dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  /// Mengambil ulang jumlah dari server (lewat `TicketRepository.unreadCount`).
  /// Diabaikan bila masih ada permintaan berjalan. Galat diabaikan: titik
  /// bukan informasi penting.
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

  /// Set jumlah langsung (angka negatif dianggap 0); dipakai saat server sudah
  /// mengembalikan `meta.unread_count`. Memberi tahu pendengar hanya bila berubah.
  void setUnread(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _unread) return;
    _unread = v;
    notifyListeners();
  }

  /// Dipanggil saat keluar: nol-kan jumlah dan abaikan jawaban [refresh] yang
  /// masih berjalan dari sesi sebelumnya.
  void clear() {
    _epoch++;
    _fetching = false;
    setUnread(0);
  }
}
