import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final String category; // 'Pesanan', 'Promo', 'Info'
  final IconData icon;
  final Color iconColor;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedCategory = 'Semua';

  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'Pesanan #KK-2026-686 Siap Diambil!',
      message:
          'Pesanan Nasi Kuning Slamet kamu sudah tiba di Booth Vokasi UB. Tunjukkan kode pesanan ke petugas.',
      time: '5 menit lalu',
      category: 'Pesanan',
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppColors.success,
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      title: 'Diskon Mahasiswa Baru 20%!',
      message:
          'Nikmati potongan spesial katering makan siang di seluruh area kampus UB. Berlaku minggu ini.',
      time: '1 jam lalu',
      category: 'Promo',
      icon: Icons.local_offer_outlined,
      iconColor: AppColors.primary,
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      title: 'Menu Baru: Risoles Bu Tima',
      message:
          'Camilan gurih renyah isi ragout ayam kini hadir untuk danusan dan rapat organisasi kamu.',
      time: '3 jam lalu',
      category: 'Info',
      icon: Icons.restaurant_rounded,
      iconColor: AppColors.blue,
      isRead: false,
    ),
    NotificationItem(
      id: '4',
      title: 'Sisa 5 Porsi Nasi Kuning Slamet!',
      message:
          'Kuota menu makan siang hari ini hampir habis di booth vokasi. Pesan sebelum jam istirahat!',
      time: 'Kemarin',
      category: 'Promo',
      icon: Icons.access_time_rounded,
      iconColor: AppColors.warning,
      isRead: true,
    ),
    NotificationItem(
      id: '5',
      title: 'Gateway QRIS & Virtual Account Aktif',
      message:
          'Pembayaran instan QRIS dan VA Bank (BCA, Mandiri, BRI, BNI) dengan durasi 1 jam kini tersedia.',
      time: '2 hari lalu',
      category: 'Info',
      icon: Icons.payment_rounded,
      iconColor: AppColors.primaryDark,
      isRead: true,
    ),
  ];

  List<NotificationItem> get _filteredNotifications {
    if (_selectedCategory == 'Semua') return _notifications;
    return _notifications.where((n) => n.category == _selectedCategory).toList();
  }

  void _markAllAsRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi telah ditandai sudah dibaca'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifikasi',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tandai Dibaca',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: ['Semua', 'Pesanan', 'Promo', 'Info'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // List Notifikasi
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada notifikasi',
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kategori "$_selectedCategory" saat ini kosong.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return InkWell(
                        onTap: () {
                          setState(() => item.isRead = true);
                          if (item.category == 'Pesanan') {
                            Navigator.pushNamed(context, AppRoutes.orders);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? AppColors.surface
                                : const Color(0xFFFFF9F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead
                                  ? AppColors.cardBorder
                                  : AppColors.primary.withValues(alpha: 0.35),
                              width: item.isRead ? 1 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: item.iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: item.iconColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.time,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
