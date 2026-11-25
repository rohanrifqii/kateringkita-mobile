// Tab "Pesanan" di navigasi bawah (MainNavigationScreen) dan rute AppRoutes.orders. Berisi kolom cari dan
// tab status; daftar pesanannya sendiri dimuat dari server oleh OrderListView (GET /me/orders).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import 'order_list_view.dart';

/// Layar daftar pesanan dengan tab status (Aktif / Selesai / Dibatalkan) dan
/// kolom cari (nama menu / kode pesanan). Pencarian dikirim ke server sebagai
/// parameter `q`. Tombol kembali hanya muncul bila layar dibuka sebagai rute.
class OrdersScreen extends StatefulWidget {
  /// [initialTab]: `active` | `completed` | `cancelled`; [initialQuery] mis.
  /// kode pesanan (dipakai saat dibuka dari notifikasi).
  const OrdersScreen({super.key, this.initialTab, this.initialQuery = ''});

  final String? initialTab;
  final String initialQuery;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

/// State layar Pesanan: tab status terpilih dan kata kunci pencarian.
class _OrdersScreenState extends State<OrdersScreen> {
  // Nilai `tab` untuk server, urutannya sama dengan label [tabs].
  static const _tabKeys = ['active', 'completed', 'cancelled'];
  /// Label tab yang tampil di layar.
  static const tabs = ['Aktif', 'Selesai', 'Dibatalkan'];

  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  /// Kata kunci yang sudah dikirim ke OrderListView (setelah jeda ketik).
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Tab dan kata kunci awal dari argumen rute (mis. dari notifikasi); tab tak dikenal tetap ke "Aktif".
    final i = _tabKeys.indexOf(widget.initialTab ?? '');
    if (i >= 0) _selectedTabIndex = i;
    final q = widget.initialQuery.trim();
    if (q.isNotEmpty) {
      _searchController.text = q;
      _searchQuery = q;
    }
  }

  /// Kirim kata kunci ke daftar setelah 400 ms tanpa ketikan baru, supaya tidak memanggil server tiap huruf.
  void _onSearch(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _searchQuery = val.trim());
    });
    // Memperbarui tombol hapus (x) tanpa menunggu debounce.
    setState(() {});
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
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        Row(
                          children: [
                            if (Navigator.canPop(context)) ...[
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 20, color: AppColors.textPrimary),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              'Orders',
                              style: AppTextStyles.h2.copyWith(fontSize: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Search Orders Bar
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: AppColors.textMuted, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearch,
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama menu / kode pesanan...',
                                    hintStyle:
                                        AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _onSearch('');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: AppColors.textMuted, size: 18),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(tabs.length, (index) {
                              final isSelected = _selectedTabIndex == index;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTabIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.cardBorder,
                                      ),
                                    ),
                                    child: Text(
                                      tabs[index],
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            Expanded(
              // Key per tab: ganti tab membuat OrderListView baru (state dan
              // daftar lama dibuang, lalu dimuat ulang).
              child: OrderListView(
                key: ValueKey(_tabKeys[_selectedTabIndex]),
                tab: _tabKeys[_selectedTabIndex],
                query: _searchQuery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
