// Halaman Lacak Pesanan untuk pembeli (rute /order-tracking/<kode>), dibuka dari kartu di daftar Pesanan atau
// notifikasi status pesanan: status besar, linimasa langkah beserta jamnya, titik temu, ringkasan, dan tombol Chat.
// Data dari OrderRepository (GET /orders/:code), diperbarui tiap 15 detik; tema shadcn_ui sama dengan halaman Chat.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_shad_theme.dart';
import '../../core/app_text_styles.dart';
import '../../core/order_steps.dart';
import '../../core/pickup_time.dart';
import '../../data/order_repository.dart';
import '../../models/order_api_model.dart';
import '../../widgets/order_status_label.dart';
import '../../widgets/order_step_timeline.dart';
import 'order_chat_screen.dart';

/// Halaman Lacak Pesanan untuk satu pesanan, dibuka dengan kode pesanannya.
///
/// Detail diambil dari `GET /orders/:code` saat dibuka, lalu diambil ulang tiap
/// 15 detik. Pengambilan berhenti saat aplikasi di latar belakang atau ada
/// halaman lain di atasnya, dan langsung jalan lagi saat kembali terlihat.
/// Setelah pesanan selesai, dibatalkan, atau kedaluwarsa, cek berkala berhenti.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderCode});

  /// Kode pesanan yang dilacak, misalnya "KK-20261124-0001".
  final String orderCode;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

/// State Lacak Pesanan: detail pesanan terakhir, timer cek berkala, dan status muat/galat.
/// [WidgetsBindingObserver] dipakai untuk tahu kapan aplikasi pindah ke latar belakang.
class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  // Jeda antar-cek detail pesanan.
  static const _refreshInterval = Duration(seconds: 15);

  // Detail pesanan terakhir dari server; null sebelum pemuatan pertama berhasil.
  OrderApiModel? _order;

  // Pesan galat pemuatan; hanya tampil bila [_order] masih null.
  String? _errorMessage;

  // Benar selama permintaan berjalan, supaya cek berkala tidak menumpuk.
  bool _fetching = false;

  // Benar bila aplikasi sedang di depan (tidak di latar belakang).
  bool _foreground = true;

  // Benar bila halaman ini rute teratas (tidak tertutup halaman lain, mis. Chat).
  bool _routeVisible = true;

  // Timer cek berkala; dibatalkan di dispose atau saat pesanan berakhir.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Halaman lain menutupi halaman ini: berhenti; kembali terlihat: cek lagi.
    final wasVisible = _routeVisible;
    _routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeVisible && !wasVisible) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Cek berkala: hanya saat terlihat, di depan, tidak sedang mengambil, dan
  // pesanan belum berakhir (status akhir tidak akan berubah lagi).
  void _refresh() {
    if (!mounted || !_foreground || !_routeVisible || _fetching) return;
    if (_order?.isFinished ?? false) return;
    _load();
  }

  // Mengambil detail pesanan (`GET /orders/:code`). Bila cek berkala gagal, data terakhir tetap
  // tampil; pesan galat hanya muncul bila belum ada data sama sekali.
  Future<void> _load() async {
    _fetching = true;
    try {
      // 1. Ambil detail terbaru dari server.
      final order = await context.read<OrderRepository>().get(widget.orderCode);
      if (!mounted) return;
      // 2. Simpan dan tampilkan; pesanan yang sudah berakhir tidak dicek lagi.
      setState(() {
        _order = order;
        _errorMessage = null;
      });
      if (order.isFinished) _refreshTimer?.cancel();
    } catch (error) {
      // 3. Gagal: data lama tetap tampil; galat hanya saat belum ada data.
      if (!mounted || _order != null) return;
      setState(
        () => _errorMessage = error is ApiException
            ? error.message
            : 'Terjadi kesalahan. Coba lagi.',
      );
    } finally {
      _fetching = false;
    }
  }

  // Tombol "Coba Lagi": hapus pesan galat (indikator muat tampil lagi), lalu muat ulang.
  void _retry() {
    setState(() => _errorMessage = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return ShadTheme(
      data: buildAppShadTheme(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Lacak Pesanan',
            style: AppTextStyles.h3.copyWith(fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: order != null
            ? _details(order)
            : _errorMessage != null
            ? _errorState(_errorMessage!)
            : const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: order == null ? null : _chatSection(order),
      ),
    );
  }

  // Pesan galat di tengah layar dengan tombol "Coba Lagi".
  Widget _errorState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _retry, child: const Text('Coba Lagi')),
        ],
      ),
    ),
  );

  // Isi halaman: kartu status, kartu linimasa langkah ([buildOrderSteps] → [OrderStepTimeline]), dan kartu titik
  // temu. Scroll hanya cadangan untuk layar pendek; di layar umum semuanya muat.
  Widget _details(OrderApiModel order) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusCard(order),
        const SizedBox(height: 12),
        ShadCard(
          padding: const EdgeInsets.all(20),
          child: OrderStepTimeline(steps: buildOrderSteps(order)),
        ),
        const SizedBox(height: 12),
        _pickupCard(order),
      ],
    ),
  );

  // Kartu status: nama toko dan kode, label status besar (merah bila batal/kedaluwarsa, plus alasan batal bila
  // ada), lalu jumlah menu dan total harga.
  Widget _statusCard(OrderApiModel order) {
    final isFailed = order.status == 'cancelled' || order.status == 'expired';
    final cancelReason = order.cancelReason;
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.merchantName} · ${order.code}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            orderStatusLabel(order),
            style: AppTextStyles.h1.copyWith(
              fontSize: 26,
              color: isFailed ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          if (isFailed && cancelReason != null && cancelReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Alasan: $cancelReason',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${order.items.length} menu · Total ${AppCurrency.format(order.total)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Kartu titik temu: nama dan keterangan titik, serta jam ambil (WIB) bila sudah ditentukan.
  Widget _pickupCard(OrderApiModel order) {
    final description = order.pickupPoint.description;
    final pickupAt = order.pickupAt;
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Titik temu',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.pickupPoint.name,
                  style: AppTextStyles.h4.copyWith(fontSize: 15),
                ),
                if (description != null && description.isNotEmpty)
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (pickupAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ambil ${formatWib(pickupAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Membuka halaman Chat, lalu mengambil ulang detail supaya badge pesan
  // belum dibaca ikut diperbarui (juga untuk pesanan yang sudah berakhir).
  Future<void> _openChat(OrderApiModel order) async {
    await Navigator.pushNamed(context, AppRoutes.orderChatFor(order.code));
    if (mounted && !_fetching) _load();
  }

  // Tombol Chat di bagian bawah, dengan badge jumlah pesan penjual yang
  // belum dibaca. Chat bisa dibuka saat terbuka, dan sesudah pesanan berakhir
  // untuk membaca riwayatnya. Selama pesanan menunggu, atau untuk pesanan
  // meja, tombol nonaktif dengan keterangannya.
  //
  // @param order pesanan yang sedang dilacak, beserta keadaan chat-nya.
  // @returns tombol Chat selebar layar, plus keterangan bila nonaktif.
  Widget _chatSection(OrderApiModel order) {
    // 1. Chat bisa dibuka bila tersedia dan sudah dimulai (penjual sudah
    //    menerima pesanan); sesudah pesanan berakhir pun tetap bisa dibaca.
    final chat = order.chat;
    final canOpenChat =
        chat != null && chat.available && chat.closedReason != 'not_started';
    final unreadCount = chat?.unreadCount ?? 0;
    // 2. Keterangan di bawah tombol: alasan tombol nonaktif, bila ada.
    final hint = order.status == 'holding'
        ? chatClosedText('not_started')
        : chat?.available == false
        ? chatClosedText('unavailable')
        : null;
    // 3. Tombol Chat dengan badge jumlah belum dibaca, lalu keterangannya.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadButton(
              width: double.infinity,
              enabled: canOpenChat,
              onPressed: () => _openChat(order),
              leading: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              trailing: unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              child: const Text('Chat'),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
