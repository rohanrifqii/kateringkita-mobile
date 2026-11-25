// Konten promo dari backend: banner beranda (GET /banners) dan pop-up promo (GET /popup).
// Dipanggil HomeScreen lewat Provider; promo di dalamnya berupa model Voucher.
import '../api/api_client.dart';
import '../models/voucher.dart';

/// Tujuan saat banner diketuk: voucher promo, profil toko, atau tidak ke mana-mana.
enum BannerTarget { promo, merchant, none }

/// Banner beranda dari server (`GET /banners`).
class PromoBanner {
  final int id;
  final String title;
  final String imageUrl;
  final BannerTarget target;
  final Voucher? promo;
  final VoucherMerchant? merchant;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.target,
    this.promo,
    this.merchant,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        id: json['id'] as int,
        title: json['title'] as String,
        imageUrl: json['image_url'] as String,
        target: switch (json['target']) {
          'promo' => BannerTarget.promo,
          'merchant' => BannerTarget.merchant,
          _ => BannerTarget.none,
        },
        promo: json['promo'] == null ? null : Voucher.fromJson(json['promo'] as Map<String, dynamic>),
        merchant: json['merchant'] == null
            ? null
            : VoucherMerchant.fromJson(json['merchant'] as Map<String, dynamic>),
      );
}

/// Pop-up promo saat aplikasi dibuka (`GET /popup`).
class PromoPopup {
  final int id;
  final String title;
  final String imageUrl;
  final Voucher? promo;

  const PromoPopup({required this.id, required this.title, required this.imageUrl, this.promo});

  factory PromoPopup.fromJson(Map<String, dynamic> json) => PromoPopup(
        id: json['id'] as int,
        title: json['title'] as String,
        imageUrl: json['image_url'] as String,
        promo: json['promo'] == null ? null : Voucher.fromJson(json['promo'] as Map<String, dynamic>),
      );
}

/// Konten promo yang diatur admin & penjual: banner beranda dan pop-up.
class PromoContentRepository {
  PromoContentRepository(this._api);

  final ApiClient _api;

  /// Daftar banner beranda aktif (`GET /banners`); kosong bila server mengirim null.
  Future<List<PromoBanner>> banners() async =>
      (((await _api.get('/banners')).data as List?) ?? const [])
          .map((e) => PromoBanner.fromJson(e as Map<String, dynamic>))
          .toList();

  /// Pop-up promo aktif (`GET /popup`), atau null bila tidak ada.
  Future<PromoPopup?> popup() async {
    final data = (await _api.get('/popup')).data;
    return data == null ? null : PromoPopup.fromJson(data as Map<String, dynamic>);
  }
}
