// Model jawaban Asisten AI dari backend (POST /assistant/recommendations): menu terpilih per toko.
// Dibuat oleh AssistantRepository, disimpan di riwayat (AiSession), dan ditampilkan layar Asisten AI.
import 'product_model.dart';

/// Satu menu pilihan asisten. [menu] adalah kartu menu katalog (bisa dibuka
/// ke detail / dimasukkan keranjang); qty & subtotal dihitung server.
class RecommendedItem {
  final ProductModel menu;
  final int qty;
  final int subtotal;

  /// Alasan pilihan dari AI; null bila kosong.
  final String? reason;

  const RecommendedItem({
    required this.menu,
    required this.qty,
    required this.subtotal,
    this.reason,
  });

  factory RecommendedItem.fromJson(Map<String, dynamic> json) {
    final reason = (json['reason'] as String?)?.trim();
    return RecommendedItem(
      menu: ProductModel.fromJson(json['menu'] as Map<String, dynamic>),
      qty: (json['qty'] as num).toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
      reason: (reason == null || reason.isEmpty) ? null : reason,
    );
  }
}

/// Rekomendasi dikelompokkan per toko (checkout satu toko per keranjang).
class RecommendationGroup {
  final MerchantRef merchant;
  final List<RecommendedItem> items;
  final int total;

  const RecommendationGroup({
    required this.merchant,
    required this.items,
    required this.total,
  });

  factory RecommendationGroup.fromJson(Map<String, dynamic> json) =>
      RecommendationGroup(
        merchant:
            MerchantRef.fromJson(json['merchant'] as Map<String, dynamic>),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => RecommendedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

/// Jawaban `POST /assistant/recommendations`.
///
/// `source`: `ai` (dipilih AI) atau `fallback` (AI belum aktif/gagal, atau
/// tidak ada kandidat; server memberi menu teratas yang masih tersedia).
class Recommendation {
  final String source;
  final String summary;
  final List<RecommendationGroup> groups;
  final int total;

  /// JSON mentah dari server, disimpan apa adanya sebagai snapshot riwayat.
  final Map<String, dynamic> json;

  const Recommendation({
    required this.source,
    required this.summary,
    required this.groups,
    required this.total,
    this.json = const {},
  });

  /// True bila menu dipilih AI, false bila menu cadangan (`fallback`).
  bool get isAi => source == 'ai';

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        source: (json['source'] as String?) ?? 'fallback',
        summary: (json['summary'] as String?) ?? '',
        groups: ((json['groups'] as List?) ?? const [])
            .map((e) =>
                RecommendationGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        json: json,
      );
}
