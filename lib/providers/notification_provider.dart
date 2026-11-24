// Provider jumlah notifikasi belum dibaca untuk lencana lonceng (NotificationBell) dan layar Notifikasi,
// serta jumlah chat pesanan belum dibaca untuk badge tab Pesanan (CustomBottomNavbar).
// Alur: NotificationBell/layar → NotificationProvider → NotificationRepository / OrderChatRepository → ApiClient
// → backend.
import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';
import '../data/order_chat_repository.dart';

/// Jumlah notifikasi belum dibaca (lencana lonceng beranda), dibagi antara
/// beranda dan layar Notifikasi. Bila [chatRepository] diisi, jumlah pesan
/// chat pesanan yang belum dibaca (badge tab Pesanan) ikut diambil pada cek
/// yang sama.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._repo, {OrderChatRepository? chatRepository})
      // ignore: prefer_initializing_formals
      : _chatRepository = chatRepository;

  final NotificationRepository _repo;
  final OrderChatRepository? _chatRepository;

  int _unread = 0;
  /// Jumlah notifikasi belum dibaca yang terakhir diketahui (0 untuk tamu).
  int get unreadCount => _unread;

  int _chatUnread = 0;

  /// Jumlah pesan penjual yang belum dibaca di semua pesanan pembeli.
  int get chatUnreadCount => _chatUnread;

  /// Mencegah permintaan ganda saat refresh dipanggil berulang.
  bool _fetching = false;

  /// Naik saat [clear]; jawaban dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  /// Ambil ulang jumlah notifikasi dan chat belum dibaca dari server, keduanya
  /// bersamaan. Diabaikan bila permintaan sebelumnya belum selesai. Galat
  /// diabaikan (lencana tetap), masing-masing tanpa saling memengaruhi.
  Future<void> refresh() async {
    if (_fetching) return;
    final epoch = _epoch;
    _fetching = true;
    try {
      await Future.wait([_refreshNotifications(epoch), _refreshChat(epoch)]);
    } finally {
      if (epoch == _epoch) _fetching = false;
    }
  }

  /// Jumlah notifikasi belum dibaca (GET /me/notifications lewat
  /// [NotificationRepository.unreadCount]);
  /// hasilnya dibuang bila [epoch] sudah usang (pengguna keluar di tengah jalan).
  Future<void> _refreshNotifications(int epoch) async {
    try {
      final unreadCount = await _repo.unreadCount();
      if (epoch == _epoch) setUnread(unreadCount);
    } catch (_) {
      // Lencana bukan informasi penting; coba lagi pada jadwal berikutnya.
    }
  }

  /// Jumlah chat belum dibaca (GET /me/chats/unread); dilewati bila provider
  /// dibuat tanpa [OrderChatRepository].
  Future<void> _refreshChat(int epoch) async {
    final chatRepository = _chatRepository;
    if (chatRepository == null) return;
    try {
      final total = await chatRepository.unreadTotal();
      if (epoch == _epoch) _setChatUnread(total);
    } catch (_) {
      // Sama dengan lonceng: coba lagi pada jadwal berikutnya.
    }
  }

  /// Simpan [total] chat belum dibaca (negatif dianggap 0); beri tahu
  /// pendengar hanya bila nilainya berubah.
  void _setChatUnread(int total) {
    final value = total < 0 ? 0 : total;
    if (value == _chatUnread) return;
    _chatUnread = value;
    notifyListeners();
  }

  /// Setel jumlah notifikasi belum dibaca ke [n] (negatif dianggap 0). Dipakai
  /// saat server sudah mengembalikan `unread_count` (daftar/tandai).
  void setUnread(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _unread) return;
    _unread = v;
    notifyListeners();
  }

  /// Dipanggil saat keluar / sesi tidak valid: lencana lonceng dan badge chat
  /// jadi 0, dan jawaban permintaan yang masih berjalan diabaikan.
  void clear() {
    _epoch++;
    _fetching = false;
    setUnread(0);
    _setChatUnread(0);
  }
}
