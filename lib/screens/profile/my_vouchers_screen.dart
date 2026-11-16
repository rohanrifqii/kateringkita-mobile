import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../data/voucher_repository.dart';
import '../../models/voucher.dart';
import '../../widgets/voucher_card.dart';

/// Voucher Saya: voucher platform yang bisa diklaim ("Voucher KateringKita")
/// + voucher yang sudah diklaim, dipisah Bisa dipakai / Kedaluwarsa.
class MyVouchersScreen extends StatefulWidget {
  const MyVouchersScreen({super.key});

  @override
  State<MyVouchersScreen> createState() => _MyVouchersScreenState();
}

class _MyVouchersScreenState extends State<MyVouchersScreen> {
  List<Voucher> _platform = const [];
  List<Voucher> _mine = const [];
  bool _loading = true;
  String? _error;
  bool _expiredTab = false;
  int? _claiming;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = context.read<VoucherRepository>();
    try {
      final hasil = await Future.wait([repo.platform(), repo.mine()]);
      if (!mounted) return;
      setState(() {
        _platform = hasil[0].where((v) => !v.claimed).toList();
        _mine = hasil[1];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Voucher belum bisa dimuat. Coba lagi.';
      });
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> _claim(Voucher v) async {
    if (_claiming != null) return;
    final repo = context.read<VoucherRepository>();
    setState(() => _claiming = v.id);
    try {
      await repo.claim(v.id);
      await _load();
      if (mounted) _snack('Voucher disimpan ke Voucher Saya');
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Voucher belum bisa diklaim. Coba lagi.');
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  bool _expired(Voucher v) => !v.endsAt.isAfter(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final aktif = _mine.where((v) => !_expired(v)).toList();
    final lewat = _mine.where(_expired).toList();
    final tampil = _expiredTab ? lewat : aktif;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Voucher Saya', style: AppTextStyles.h3),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                    TextButton(onPressed: _load, child: const Text('Coba Lagi')),
                  ],
                  if (_platform.isNotEmpty) ...[
                    Text('Voucher KateringKita', style: AppTextStyles.h4),
                    const SizedBox(height: 4),
                    Text('Berlaku di semua toko untuk bayar non-tunai.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Column(
                      key: const ValueKey('voucher-platform-list'),
                      children: [
                        for (final v in _platform)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VoucherCard(
                              voucher: v,
                              width: null,
                              busy: _claiming == v.id,
                              onClaim: () => _claim(v),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Bisa dipakai (${aktif.length})'),
                        selected: !_expiredTab,
                        onSelected: (_) => setState(() => _expiredTab = false),
                      ),
                      ChoiceChip(
                        label: Text('Kedaluwarsa (${lewat.length})'),
                        selected: _expiredTab,
                        onSelected: (_) => setState(() => _expiredTab = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_mine.isEmpty && _platform.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('Belum ada voucher. Klaim dari halaman toko atau Voucher KateringKita.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    ),
                  Column(
                    key: const ValueKey('voucher-saya-list'),
                    children: [
                      for (final v in tampil)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          // tanpa tombol: sudah diklaim; dipakai lewat checkout
                          child: VoucherCard(voucher: v, width: null, action: const SizedBox.shrink()),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
