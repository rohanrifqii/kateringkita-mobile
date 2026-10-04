import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../models/product_model.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  final List<Map<String, dynamic>> _likedItems = const [
    {
      'name': 'Lumpia Diego',
      'price': 129.99,
      'image': 'assets/images/lumpia_diego.png',
      'product': ProductData.defaultProduct,
    },
    {
      'name': 'Donat Surgawi',
      'price': 109.00,
      'image': 'assets/images/donat_surgawi.png',
      'product': ProductData.defaultProduct,
    },
    {
      'name': 'Risoles Bu Tima',
      'price': 124.00,
      'image': 'assets/images/risoles.png',
      'product': ProductData.defaultProduct,
    },
    {
      'name': 'Martabak Pecenongan',
      'price': 79.00,
      'image': 'assets/images/martabak.png',
      'product': ProductData.defaultProduct,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Liked',
                style: AppTextStyles.h2.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Text(
                '4 Menu Favorit Tersimpan',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),

              // Favorites List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _likedItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _likedItems[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
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
                          child: Image.asset(
                            item['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: AppTextStyles.h4.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${(item['price'] as double).toStringAsFixed(2)}',
                                style: AppTextStyles.price.copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        // Heart Icon
                        const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        // + Order Button
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.productDetail);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '+ Order',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
