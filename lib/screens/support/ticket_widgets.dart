import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../models/support_ticket.dart';

/// Chip status tiket: Menunggu admin / Dibalas / Ditutup.
class TicketStatusChip extends StatelessWidget {
  const TicketStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'answered' => (AppColors.successLight, AppColors.successDark),
      'closed' => (AppColors.secondaryBg, AppColors.textSecondary),
      _ => (AppColors.warningLight, const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        ticketStatusLabel(status),
        style: AppTextStyles.bodySmall
            .copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// Kartu arahan: urusan pesanan lebih cepat langsung ke penjual.
class SellerWhatsAppHint extends StatelessWidget {
  const SellerWhatsAppHint({
    super.key,
    required this.text,
    this.action,
  });

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_rounded,
              color: AppColors.successDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
