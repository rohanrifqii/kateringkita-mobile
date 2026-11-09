import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_currency.dart';
import '../core/app_text_styles.dart';

enum AppModalType { question, success }

/// Modal popup dialog kustom sesuai desain Figma KateringKita.
class AppModalDialog extends StatelessWidget {
  final AppModalType type;
  final String title;
  final String message;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;

  const AppModalDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
  });

  /// Menampilkan modal dialog secara umum dengan transisi halus
  static Future<T?> show<T>({
    required BuildContext context,
    required AppModalType type,
    required String title,
    required String message,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return AppModalDialog(
          type: type,
          title: title,
          message: message,
          primaryButtonText: primaryButtonText,
          onPrimaryPressed: onPrimaryPressed,
          secondaryButtonText: secondaryButtonText,
          onSecondaryPressed: onSecondaryPressed,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  /// 1. Modal Konfirmasi Logout
  static Future<bool?> showLogout(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) {
    return show<bool>(
      context: context,
      type: AppModalType.question,
      title: 'Keluar dari Akun?',
      message:
          'Apakah Anda yakin ingin keluar? Anda harus login kembali untuk mengakses layanan KateringKita.',
      primaryButtonText: 'Ya, Keluar',
      secondaryButtonText: 'Batal',
      onPrimaryPressed: () async {
        Navigator.pop(context, true);
        await onConfirm();
      },
      onSecondaryPressed: () => Navigator.pop(context, false),
    );
  }

  /// 2. Modal Konfirmasi Proses Pembayaran di Checkout
  static Future<bool?> showPaymentConfirmation(
    BuildContext context, {
    required double total,
    required VoidCallback onConfirm,
  }) {
    return show<bool>(
      context: context,
      type: AppModalType.question,
      title: 'Konfirmasi Pembayaran',
      message:
          'Kamu akan melakukan pembayaran sebesar ${AppCurrency.format(total)}. Pastikan pesanan dan lokasi pengambilan sudah sesuai.',
      primaryButtonText: 'Ya, Bayar Sekarang',
      secondaryButtonText: 'Batal, periksa lagi',
      onPrimaryPressed: () {
        Navigator.pop(context, true);
        onConfirm();
      },
      onSecondaryPressed: () => Navigator.pop(context, false),
    );
  }

  /// 3. Modal Password Berhasil Diperbarui
  static Future<void> showPasswordResetSuccess(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    return show(
      context: context,
      barrierDismissible: false,
      type: AppModalType.success,
      title: 'Kata Sandi Diperbarui!',
      message:
          'Kata sandi baru kamu berhasil disimpan. Silakan masuk kembali menggunakan kata sandi baru kamu.',
      primaryButtonText: 'Masuk Sekarang',
      onPrimaryPressed: () {
        Navigator.pop(context);
        onConfirm();
      },
    );
  }

  /// 4. Modal Berhasil Login
  static Future<void> showLoginSuccess(
    BuildContext context, {
    required VoidCallback onConfirm,
    String? message,
  }) {
    return show(
      context: context,
      barrierDismissible: false,
      type: AppModalType.success,
      title: 'Anda Berhasil Login!',
      message: message ??
          'Kata sandi baru Anda telah disimpan. Silakan login kembali dengan kata sandi baru Anda.',
      primaryButtonText: 'Ke Beranda',
      onPrimaryPressed: () {
        Navigator.pop(context);
        onConfirm();
      },
    );
  }

  /// 5. Modal Pusat Bantuan (Customer Service WhatsApp)
  static Future<void> showCustomerSupport(
    BuildContext context, {
    required VoidCallback onWhatsAppPressed,
  }) {
    return show(
      context: context,
      type: AppModalType.question,
      title: 'Pusat Bantuan',
      message:
          'Kamu akan diarahkan ke Costumer Service KateringKita via WhatsApp untuk bantuan kendala pesanan, katering, atau pertanyaan lainnya.',
      primaryButtonText: 'Hubungi via WhatsApp',
      secondaryButtonText: 'Batal',
      onPrimaryPressed: () {
        Navigator.pop(context);
        onWhatsAppPressed();
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isQuestion = type == AppModalType.question;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lingkaran Icon Badge Oranye
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary, // Solid orange #E27244
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isQuestion
                    ? const Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // Judul Modal
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Deskripsi / Pesan
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),

            // Tombol Utama (Primary)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onPrimaryPressed,
                child: Text(
                  primaryButtonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Tombol Kedua (Batal / Secondary) jika ada
            if (secondaryButtonText != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSecondaryPressed,
                  child: Text(
                    secondaryButtonText!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
