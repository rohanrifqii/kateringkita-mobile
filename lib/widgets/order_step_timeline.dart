// Gambar urutan langkah pesanan (titik, garis, label, jam WIB) untuk halaman
// Lacak Pesanan. Warna mengikuti satu aksen oranye; langkah gagal merah,
// langkah yang belum terjadi abu-abu.
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/order_steps.dart';
import '../core/pickup_time.dart';

/// Daftar langkah pesanan dari atas ke bawah, satu baris per langkah.
///
/// Langkah yang sudah lewat dan yang sedang berjalan menampilkan jamnya dalam
/// WIB (misalnya "09:05", atau "23 Nov 09:05" bila bukan hari ini). Langkah
/// yang belum terjadi tidak punya jam.
class OrderStepTimeline extends StatelessWidget {
  const OrderStepTimeline({super.key, required this.steps});

  /// Langkah yang digambar, biasanya hasil `buildOrderSteps`.
  final List<OrderStep> steps;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < steps.length; i++)
        _StepRow(step: steps[i], isLast: i == steps.length - 1),
    ],
  );
}

/// Satu baris langkah: titik bulat, garis penghubung ke langkah berikutnya,
/// label, dan jam di sisi kanan.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final OrderStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // 1. Pilih warna dan ikon titik sesuai keadaan langkah.
    final (dotColor, icon) = switch (step.state) {
      OrderStepState.done => (AppColors.primary, Icons.check_rounded),
      OrderStepState.current => (AppColors.primary, Icons.circle),
      OrderStepState.failed => (AppColors.danger, Icons.close_rounded),
      OrderStepState.upcoming => (AppColors.cardBorder, null),
    };
    final isUpcoming = step.state == OrderStepState.upcoming;
    final labelColor = switch (step.state) {
      OrderStepState.failed => AppColors.danger,
      OrderStepState.upcoming => AppColors.textMuted,
      _ => AppColors.textPrimary,
    };
    final at = step.at;

    // 2. Susun titik + garis di kiri, label dan jam di kanan.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUpcoming ? AppColors.surface : dotColor,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: icon == null
                    ? null
                    : Icon(
                        icon,
                        size: step.state == OrderStepState.current ? 8 : 14,
                        color: Colors.white,
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.state == OrderStepState.done
                        ? AppColors.primary
                        : AppColors.cardBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 18),
              child: Text(
                step.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: labelColor,
                  fontWeight: step.state == OrderStepState.current
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
          if (at != null && !isUpcoming)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                formatWibStepTime(at),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
