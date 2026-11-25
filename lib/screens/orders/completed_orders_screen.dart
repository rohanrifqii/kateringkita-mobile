// Layar Pesanan Selesai (rute AppRoutes.completedOrders): riwayat pesanan berstatus 'completed'.
// Data lokal: dibaca dari database Drift di perangkat (AppDb.watchOrders), belum dari backend.
import '../../widgets/menu_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../models/product_model.dart';

/// Layar daftar pesanan berstatus 'completed' yang tersimpan di database lokal; ikut diperbarui saat tabel berubah.
class CompletedOrdersScreen extends StatelessWidget {
  const CompletedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDb>();

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
      body: SafeArea(
        child: StreamBuilder<List<Order>>(
          stream: db.watchOrders(),
          builder: (context, snapshot) {
            final allOrders = snapshot.data ?? [];
            final completedOrders = allOrders
                .where((o) => o.status.toLowerCase() == 'completed')
                .toList();

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (completedOrders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          size: 32,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada pesanan selesai',
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pesanan yang sudah kamu ambil dan selesaikan akan tercatat di sini.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: completedOrders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = completedOrders[index];
                // Mencari data produk lokal berdasarkan nama; getProductByName masih shim yang selalu
                // mengembalikan null, jadi gambar memakai placeholder MenuImage.
                final product = ProductData.getProductByName(order.productName);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MenuImage(product?.imageUrl,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.productName,
                              style: AppTextStyles.h4.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.quantity} Porsi • ${AppCurrency.format(order.totalPrice)} • Selesai',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        // Pesan lagi: membuka detail produk. Karena product masih null (lihat di atas),
                        // ProductDetailScreen saat ini langsung menutup diri kembali.
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.productDetail,
                            arguments: product,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Pesan Lagi',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
