import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_exception.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/require_login.dart';
import '../data/promo_content_repository.dart';
import '../data/voucher_repository.dart';
import 'menu_image.dart';

/// Tanggal WIB "yyyy-MM-dd" untuk aturan sekali sehari.
String tanggalWib(DateTime now) {
  final w = now.toUtc().add(const Duration(hours: 7));
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${w.year}-${dua(w.month)}-${dua(w.day)}';
}

String _kunci(int id) => 'popup_seen_$id';

/// Tampilkan pop-up promo bila belum tampil hari ini (WIB) dan vouchernya
/// belum diklaim. Dicatat saat tampil, jadi menutup atau mengklaim sama-sama
/// menahan pop-up sampai besok.
Future<void> maybeShowPromoPopup(BuildContext context, PromoPopup popup) async {
  if (popup.promo?.claimed ?? false) return;
  final prefs = await SharedPreferences.getInstance();
  final hariIni = tanggalWib(DateTime.now());
  if (prefs.getString(_kunci(popup.id)) == hariIni) return;
  if (!context.mounted) return;
  await prefs.setString(_kunci(popup.id), hariIni);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  await showDialog<void>(
    context: context,
    builder: (_) => PromoPopupDialog(popup: popup, messenger: messenger),
  );
}

/// Pop-up promo: gambar 3:4, judul, tombol Klaim voucher (bila ada), tutup.
class PromoPopupDialog extends StatefulWidget {
  const PromoPopupDialog({super.key, required this.popup, required this.messenger});

  final PromoPopup popup;
  final ScaffoldMessengerState messenger;

  @override
  State<PromoPopupDialog> createState() => _PromoPopupDialogState();
}

class _PromoPopupDialogState extends State<PromoPopupDialog> {
  bool _sibuk = false;

  Future<void> _klaim() async {
    final v = widget.popup.promo!;
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    setState(() => _sibuk = true);
    try {
      await context.read<VoucherRepository>().claim(v.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.messenger.showSnackBar(const SnackBar(
          content: Text('Voucher disimpan ke Voucher Saya'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      widget.messenger.showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : 'Voucher belum bisa diklaim. Coba lagi.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.popup;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Tutup',
              style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: AppColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: 3 / 4, child: MenuImage(p.imageUrl, fit: BoxFit.cover)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(p.title, textAlign: TextAlign.center, style: AppTextStyles.h3),
                        if (p.promo != null) ...[
                          const SizedBox(height: 4),
                          Text(p.promo!.label,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _sibuk ? null : _klaim,
                            child: Text(_sibuk ? 'Mengklaim…' : 'Klaim voucher'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
