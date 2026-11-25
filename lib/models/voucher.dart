// Model voucher dari backend: voucher toko/platform yang bisa diklaim, Voucher Saya, dan voucher
// yang terpakai di ringkasan harga checkout. Dibuat oleh VoucherRepository, PromoContentRepository
// dan model pesanan; ditampilkan lewat VoucherCard dan pemilih voucher.
import '../core/app_currency.dart';

/// Slot voucher di checkout: maks satu voucher toko + satu voucher platform.
enum VoucherSlot { toko, platform }

/// Toko pemilik voucher toko.
class VoucherMerchant {
  final int id;
  final String slug;
  final String businessName;

  const VoucherMerchant({
    required this.id,
    required this.slug,
    required this.businessName,
  });

  factory VoucherMerchant.fromJson(Map<String, dynamic> json) =>
      VoucherMerchant(
        id: json['id'] as int,
        slug: json['slug'] as String,
        businessName: json['business_name'] as String,
      );
}

/// Voucher (promo publik yang bisa diklaim). [usable] & [reason] hanya ada
/// dari Voucher Saya (`GET /me/vouchers`); [reason] berisi alasan voucher
/// tidak bisa dipakai untuk keranjang saat ini.
class Voucher {
  final int id;
  final String code;
  final String? description;

  /// `percent` | `fixed` | `free_service_fee`.
  final String type;
  final int value;
  final int? maxDiscount;
  final int minSubtotal;
  final DateTime endsAt;
  final VoucherSlot slot;
  final VoucherMerchant? merchant;
  final bool soldOut;
  final bool claimed;
  final bool? usable;
  final String? reason;

  const Voucher({
    required this.id,
    required this.code,
    this.description,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.minSubtotal,
    required this.endsAt,
    required this.slot,
    this.merchant,
    this.soldOut = false,
    this.claimed = false,
    this.usable,
    this.reason,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['id'] as int,
        code: json['code'] as String,
        description: json['description'] as String?,
        type: json['type'] as String,
        value: (json['value'] as num).toInt(),
        maxDiscount: (json['max_discount'] as num?)?.toInt(),
        minSubtotal: (json['min_subtotal'] as num?)?.toInt() ?? 0,
        endsAt: DateTime.parse(json['ends_at'] as String),
        slot: json['slot'] == 'platform' ? VoucherSlot.platform : VoucherSlot.toko,
        merchant: json['merchant'] == null
            ? null
            : VoucherMerchant.fromJson(json['merchant'] as Map<String, dynamic>),
        soldOut: json['sold_out'] as bool? ?? false,
        claimed: json['claimed'] as bool? ?? false,
        usable: json['usable'] as bool?,
        reason: json['reason'] as String?,
      );

  /// Salinan voucher dengan status [claimed] diganti (mis. setelah berhasil klaim).
  Voucher copyWith({bool? claimed}) => Voucher(
        id: id,
        code: code,
        description: description,
        type: type,
        value: value,
        maxDiscount: maxDiscount,
        minSubtotal: minSubtotal,
        endsAt: endsAt,
        slot: slot,
        merchant: merchant,
        soldOut: soldOut,
        claimed: claimed ?? this.claimed,
        usable: usable,
        reason: reason,
      );

  /// Teks besaran potongan: "Diskon 10% s.d. Rp 5.000", "Potongan Rp 3.000",
  /// atau "Gratis biaya layanan" (untuk tipe selain percent/fixed).
  String get label => switch (type) {
        'percent' => maxDiscount == null
            ? 'Diskon $value%'
            : 'Diskon $value% s.d. ${AppCurrency.format(maxDiscount!)}',
        'fixed' => 'Potongan ${AppCurrency.format(value)}',
        _ => 'Gratis biaya layanan',
      };

  /// Teks syarat minimal belanja, mis. "Min. belanja Rp 20.000".
  String get minLabel => minSubtotal > 0
      ? 'Min. belanja ${AppCurrency.format(minSubtotal)}'
      : 'Tanpa minimal belanja';
}

/// Voucher yang terpakai di ringkasan harga/quote pesanan (`vouchers_applied`);
/// [amount] = besar potongan dalam rupiah.
class AppliedVoucher {
  final int id;
  final String code;
  final VoucherSlot slot;
  final int amount;

  const AppliedVoucher({
    required this.id,
    required this.code,
    required this.slot,
    required this.amount,
  });

  factory AppliedVoucher.fromJson(Map<String, dynamic> json) => AppliedVoucher(
        id: json['id'] as int,
        code: json['code'] as String,
        slot: json['slot'] == 'platform' ? VoucherSlot.platform : VoucherSlot.toko,
        amount: (json['amount'] as num).toInt(),
      );
}
