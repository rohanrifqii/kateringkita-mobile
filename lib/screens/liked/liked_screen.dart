import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/liked_store.dart';
import '../../models/product_model.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: LikedStore.likedNotifier,
          builder: (context, likedIds, child) {
            final likedProducts = ProductData.mockProducts
                .where((p) => likedIds.contains(p.id))
                .toList();

            return SingleChildScrollView(
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
                    '${likedProducts.length} Menu Favorit Tersimpan',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (likedProducts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                color: AppColors.dangerLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                size: 32,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada menu favorit',
                              style: AppTextStyles.h3.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tekan ikon hati pada menu untuk menyimpannya di sini.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: likedProducts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final product = likedProducts[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.cardBorder
                                    .withValues(alpha: 0.8)),
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
                                  product.image,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 60,
                                    height: 60,
                                    color: AppColors.secondaryBg,
                                    child: const Icon(Icons.fastfood,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: AppTextStyles.h4
                                          .copyWith(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppCurrency.format(product.price),
                                      style: AppTextStyles.price
                                          .copyWith(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              // Heart Icon (can tap to unlike!)
                              IconButton(
                                icon: const Icon(
                                  Icons.favorite_rounded,
                                  color: AppColors.danger,
                                  size: 22,
                                ),
                                onPressed: () async {
                                  await LikedStore.toggleLike(product.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Dihapus dari favorit: ${product.name}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              // + Order Button
                              GestureDetector(
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
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
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
            );
          },
        ),
      ),
    );
  }
}
