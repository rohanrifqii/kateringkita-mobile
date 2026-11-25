// Lembar bawah pemilih voucher di Checkout (satu untuk slot toko, satu untuk slot platform).
// Data dari VoucherRepository: GET /me/vouchers (sesuai keranjang), GET /vouchers/platform, dan klaim.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../data/voucher_repository.dart';
import '../models/voucher.dart';
import 'voucher_card.dart';

/// Lembar pemilih voucher untuk satu slot di checkout. Voucher yang sudah
/// diklaim tampil dengan status dari server (`usable`/`reason` sesuai keranjang);
/// slot platform juga menampilkan voucher platform publik yang belum diklaim
/// ("Klaim & pakai"). Mengembalikan voucher yang dipilih, atau null.
Future<Voucher?> showVoucherPicker(
  BuildContext context, {
  required VoucherSlot slot,
  required int merchantId,
  required int subtotal,
  required String paymentMethod,
}) =>
    showModalBottomSheet<Voucher>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VoucherPicker(
          slot: slot, merchantId: merchantId, subtotal: subtotal, paymentMethod: paymentMethod),
    );

class _VoucherPicker extends StatefulWidget {
  const _VoucherPicker({
    required this.slot,
    required this.merchantId,
    required this.subtotal,
    required this.paymentMethod,
  });

  final VoucherSlot slot;
  final int merchantId;
  final int subtotal;
  final String paymentMethod;

  @override
  State<_VoucherPicker> createState() => _VoucherPickerState();
}

class _VoucherPickerState extends State<_VoucherPicker> {
  List<Voucher> _mine = const [];
  List<Voucher> _claimable = const [];
  bool _loading = true;
  String? _error;
  int? _claiming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Memuat Voucher Saya untuk keranjang ini (hanya slot yang sama dan belum kedaluwarsa)
  /// dan, untuk slot platform, voucher platform yang belum diklaim dan belum habis.
  Future<void> _load() async {
    final repo = context.read<VoucherRepository>();
    try {
      final mine = await repo.mine(
          merchantId: widget.merchantId, subtotal: widget.subtotal, paymentMethod: widget.paymentMethod);
      final platform = widget.slot == VoucherSlot.platform ? await repo.platform() : const <Voucher>[];
      if (!mounted) return;
      setState(() {
        _mine = mine.where((v) => v.slot == widget.slot && v.endsAt.isAfter(DateTime.now())).toList();
        _claimable = platform.where((v) => !v.claimed && !v.soldOut).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Voucher belum bisa dimuat. Coba lagi.';
      });
    }
  }

  /// Klaim voucher platform lalu langsung tutup lembar dengan voucher hasil klaim;
  /// bila gagal, pesan galat tampil di atas daftar.
  Future<void> _claimAndUse(Voucher v) async {
    final repo = context.read<VoucherRepository>();
    setState(() => _claiming = v.id);
    try {
      final hasil = await repo.claim(v.id);
      if (mounted) Navigator.pop(context, hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = null;
        _error = e is ApiException ? e.message : 'Voucher belum bisa diklaim. Coba lagi.';
      });
    }
  }

  Widget _tombol(String teks, VoidCallback? onTap) => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Text(teks),
      );

  @override
  Widget build(BuildContext context) {
    final judul = widget.slot == VoucherSlot.toko ? 'Pilih voucher toko' : 'Pilih voucher platform';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(judul, style: AppTextStyles.h3),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                        ),
                      for (final v in _mine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VoucherCard(
                            voucher: v,
                            width: null,
                            // "Pakai" hanya aktif bila server menyatakan voucher bisa dipakai untuk keranjang ini.
                            action: _tombol('Pakai', v.usable == true ? () => Navigator.pop(context, v) : null),
                          ),
                        ),
                      for (final v in _claimable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VoucherCard(
                            voucher: v,
                            width: null,
                            action: _tombol('Klaim & pakai', _claiming == null ? () => _claimAndUse(v) : null),
                          ),
                        ),
                      if (_mine.isEmpty && _claimable.isEmpty && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            widget.slot == VoucherSlot.toko
                                ? 'Belum ada voucher toko. Klaim di halaman toko.'
                                : 'Belum ada voucher platform yang bisa dipakai.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
