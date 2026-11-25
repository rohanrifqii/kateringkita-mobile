// Layar Pencarian menu, dibuka dari kolom/ikon cari di Beranda (AppRoutes.search).
// Hasil diambil lewat CatalogRepository.menus(q: ...) dari backend REST KateringKita (GET /menus).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_exception.dart';
import '../../data/catalog_repository.dart';
import '../../models/product_model.dart';
import '../../widgets/menu_image.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';

/// Layar pencarian menu: mengetik kata kunci lalu menampilkan menu yang cocok dari backend.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<ProductModel> _results = const [];
  bool _loading = true;
  String? _error;
  // Nomor urut permintaan: jawaban pencarian lama yang datang terlambat diabaikan.
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    // Pencarian awal dengan kata kunci kosong (menampilkan semua menu) setelah frame pertama.
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  /// Debounce 400 ms: pencarian baru dikirim setelah pengguna berhenti mengetik.
  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  /// Mengirim kata kunci ke backend; ApiException menampilkan pesan server, galat lain pesan umum.
  Future<void> _search() async {
    if (!mounted) return;
    final repo = context.read<CatalogRepository>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await repo.menus(q: _searchController.text.trim());
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = page.items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
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
                  onChanged: _onChanged,
                  style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari menu, katering, danus...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Results List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _search,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'Menu tidak ditemukan.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _results.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.productDetailFor(item.id),
                        arguments: item,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.7),
                        ),
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
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: MenuImage(item.imageUrl),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.h4.copyWith(
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      AppCurrency.format(
                                        item.price,
                                      ),
                                      style: AppTextStyles.price.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.warning,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.ratingAvg.toStringAsFixed(1),
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
                          Icon(
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
