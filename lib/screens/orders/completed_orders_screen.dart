// Layar terpisah berisi daftar pesanan selesai (rute AppRoutes.completedOrders). Isinya OrderListView tab
// 'completed' yang memuat data dari server (GET /me/orders?tab=completed). Tab Pesanan utama memakai OrdersScreen.
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import 'order_list_view.dart';

/// Layar daftar pesanan selesai milik pengguna yang login, diambil dari server
/// lewat [OrderListView] (termasuk tombol Pesan Lagi dan Beri Ulasan).
class CompletedOrdersScreen extends StatelessWidget {
  const CompletedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Completed Orders',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
      body: const SafeArea(child: OrderListView(tab: 'completed')),
    );
  }
}
