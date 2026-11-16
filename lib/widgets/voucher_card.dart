import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/voucher.dart';

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// "s.d. 30 Nov" (WIB).
String sampaiTanggal(DateTime utc) {
  final w = utc.toUtc().add(const Duration(hours: 7));
  return 's.d. ${w.day} ${_bulan[w.month - 1]}';
}

/// Kartu voucher ala tiket: jenis potongan, minimal belanja, masa berlaku,
/// tombol Klaim / Diklaim / Habis. [action] menggantikan tombol bawaan
/// (mis. "Pakai" di pemilih checkout).
class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    this.onClaim,
    this.busy = false,
    this.action,
    this.width = 250,
  });

  final Voucher voucher;
  final VoidCallback? onClaim;
  final bool busy;
  final Widget? action;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final platform = v.slot == VoucherSlot.platform;
    final aksen = platform ? AppColors.blue : AppColors.primary;
    final tombol = action ??
        FilledButton(
          onPressed: v.claimed || v.soldOut || busy ? null : onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: aksen,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: Text(v.claimed ? 'Diklaim' : v.soldOut ? 'Habis' : 'Klaim'),
        );
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: aksen.withValues(alpha: 0.35)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: aksen,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(v.minLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (platform) 'KateringKita' else v.merchant?.businessName ?? 'Toko',
                        sampaiTanggal(v.endsAt),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                    if (v.reason != null) ...[
                      const SizedBox(height: 4),
                      Text(v.reason!,
                          style: AppTextStyles.bodySmall
                              .copyWith(fontSize: 11, color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: tombol),
            ),
          ],
        ),
      ),
    );
  }
}
