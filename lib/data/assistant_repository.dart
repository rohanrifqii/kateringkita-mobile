import '../api/api_client.dart';
import '../models/recommendation.dart';

/// Asisten AI pembeli lewat backend (`POST /assistant/recommendations`).
/// Kunci AI & kuota ada di server; aplikasi tidak memanggil penyedia AI.
class AssistantRepository {
  AssistantRepository(this._api);

  final ApiClient _api;

  /// [question] 3–500 karakter. [budget] Rp 1.000–100.000.000 dan
  /// [portions] 1–1.000 bila diisi. Server membatasi 10 pertanyaan per 10
  /// menit (429) dan memberi menu cadangan bila AI tidak tersedia.
  Future<Recommendation> recommend({
    required String question,
    int? budget,
    int? portions,
    String? category,
    String? merchant,
    int? pickupPointId,
  }) async {
    final res = await _api.post('/assistant/recommendations', body: {
      'question': question.trim(),
      'budget': ?budget,
      'portions': ?portions,
      'category': ?category,
      'merchant': ?merchant,
      'pickup_point_id': ?pickupPointId,
    });
    return Recommendation.fromJson(res.data as Map<String, dynamic>);
  }
}
