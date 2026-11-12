import 'recommendation.dart';

/// Satu sesi Asisten AI yang disimpan di perangkat: pertanyaan, parameter,
/// dan snapshot jawaban server saat [savedAt]. Harga & stok di snapshot bisa
/// sudah berubah; layar menawarkan "Perbarui" untuk memanggil ulang API.
class AiSession {
  final String id;
  final String question;
  final int? budget;
  final int? portions;
  final int? sellPrice;
  final String? category;
  final Recommendation result;
  final DateTime savedAt;

  const AiSession({
    required this.id,
    required this.question,
    this.budget,
    this.portions,
    this.sellPrice,
    this.category,
    required this.result,
    required this.savedAt,
  });

  AiSession withSellPrice(int? value) => AiSession(
        id: id,
        question: question,
        budget: budget,
        portions: portions,
        sellPrice: value,
        category: category,
        result: result,
        savedAt: savedAt,
      );

  AiSession withResult(Recommendation value, DateTime at) => AiSession(
        id: id,
        question: question,
        budget: budget,
        portions: portions,
        sellPrice: sellPrice,
        category: category,
        result: value,
        savedAt: at,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'budget': budget,
        'portions': portions,
        'sell_price': sellPrice,
        'category': category,
        'result': result.json,
        'saved_at': savedAt.toUtc().toIso8601String(),
      };

  /// null bila data rusak/tidak lengkap.
  static AiSession? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final j = Map<String, dynamic>.from(raw);
      final result = j['result'];
      if (result is! Map) return null;
      int? n(String k) => (j[k] as num?)?.toInt();
      return AiSession(
        id: j['id'] as String,
        question: j['question'] as String,
        budget: n('budget'),
        portions: n('portions'),
        sellPrice: n('sell_price'),
        category: j['category'] as String?,
        result: Recommendation.fromJson(Map<String, dynamic>.from(result)),
        savedAt: DateTime.parse(j['saved_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
