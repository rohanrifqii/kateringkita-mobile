import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../models/product_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController =
      TextEditingController(text: 'Lumpia Diego, Martabak...');

  final List<Map<String, dynamic>> _searchResults = [
    {
      'name': 'Martabak Pecenongan',
      'price': 79.0,
      'rating': 4.8,
      'image': 'assets/images/martabak.png',
      'product': ProductData.mockProducts[1],
    },
    {
      'name': 'Nasi Kuning Slamet',
      'price': 94.0,
      'rating': 4.9,
      'image': 'assets/images/nasi_kuning.png',
      'product': ProductData.mockProducts[2],
    },
    {
      'name': 'Donat Surgawi',
      'price': 109.0,
      'rating': 4.7,
      'image': 'assets/images/donat_surgawi.png',
      'product': ProductData.mockProducts[3],
    },
    {
      'name': 'Risoles Bu Tima',
      'price': 124.0,
      'rating': 4.8,
      'image': 'assets/images/risoles.png',
      'product': ProductData.mockProducts[4],
    },
    {
      'name': 'Lumpia Diego',
      'price': 139.0,
      'rating': 4.6,
      'image': 'assets/images/lumpia_diego.png',
      'product': ProductData.mockProducts[0],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Search',
                    style: AppTextStyles.h2.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.textPrimary),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Results List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.productDetail,
                        arguments: item['product'],
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: AppTextStyles.h4.copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '\$${(item['price'] as double).toStringAsFixed(0)}',
                                      style: AppTextStyles.price.copyWith(fontSize: 14),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.star_rounded,
                                        color: AppColors.warning, size: 16),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${item['rating']}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 22,
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
      ),
    );
  }
}
