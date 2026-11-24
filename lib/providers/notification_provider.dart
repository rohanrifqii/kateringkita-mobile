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
  int get unreadCount => _unread;

  int _chatUnread = 0;

  /// Jumlah pesan penjual yang belum dibaca di semua pesanan pembeli.
  int get chatUnreadCount => _chatUnread;

  bool _fetching = false;

  /// Naik saat [clear]; jawaban dari sesi sebelumnya diabaikan.
  int _epoch = 0;

  /// Ambil ulang jumlah notifikasi dan chat belum dibaca. Galat diabaikan
  /// (lencana tetap), masing-masing tanpa saling memengaruhi.
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

  Future<void> _refreshNotifications(int epoch) async {
    try {
      final n = await _repo.unreadCount();
      if (epoch == _epoch) setUnread(n);
    } catch (_) {
      // Lencana bukan informasi penting; coba lagi pada jadwal berikutnya.
    }
  }

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

  void _setChatUnread(int total) {
    final value = total < 0 ? 0 : total;
    if (value == _chatUnread) return;
    _chatUnread = value;
    notifyListeners();
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
    _setChatUnread(0);
  }
}
