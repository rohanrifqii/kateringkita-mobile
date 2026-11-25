// Lonceng notifikasi di beranda dengan lencana jumlah belum dibaca; mengetuknya membuka layar Notifikasi.
// Jumlah dibaca dari NotificationProvider (GET /me/notifications lewat NotificationRepository).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

/// Ikon lonceng beranda dengan lencana jumlah belum dibaca (`unread_count`).
///
/// Jumlah diambil saat muncul, saat login, sepulang dari layar Notifikasi,
/// dan tiap 30 dtk selama lonceng terlihat dan aplikasi di depan. Tamu tidak
/// memicu permintaan dan tidak melihat lencana.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  /// Jeda polling jumlah belum dibaca.
  static const pollInterval = Duration(seconds: 30);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  late final AuthProvider _auth;
  late bool _wasLoggedIn;
  Timer? _timer;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    _timer = Timer.periodic(NotificationBell.pollInterval, (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  // Lonceng dianggap terlihat bila tab aktif dan rutenya paling atas; saat
  // kembali terlihat (mis. sepulang dari layar lain) jumlah diambil ulang.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final visible =
        TickerMode.valuesOf(context).enabled && (route?.isCurrent ?? true);
    final becameVisible = visible && !_visible;
    _visible = visible;
    if (becameVisible) _refresh();
  }

  // Di latar belakang polling tidak meminta ke server; ambil ulang saat aplikasi kembali ke depan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ambil jumlah begitu pengguna baru login.
  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (now == _wasLoggedIn) return;
    _wasLoggedIn = now;
    if (now) _refresh();
  }

  // Hanya meminta ke server bila lonceng terlihat, aplikasi di depan, dan pengguna login.
  void _refresh() {
    if (!mounted || !_visible || !_foreground || !_auth.isLoggedIn) return;
    context.read<NotificationProvider>().refresh();
  }

  // Buka layar Notifikasi, lalu perbarui lencana setelah kembali.
  Future<void> _open() async {
    await Navigator.pushNamed(context, AppRoutes.notifications);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    final count = loggedIn
        ? context.select<NotificationProvider, int>((n) => n.unreadCount)
        : 0;
    return Semantics(
      button: true,
      label: count > 0
          ? 'Notifikasi, $count belum dibaca'
          : 'Notifikasi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
