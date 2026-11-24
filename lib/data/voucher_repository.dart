// Repository voucher pembeli: memanggil backend lewat ApiClient untuk klaim voucher,
// daftar Voucher Saya (layar profil & pemilih voucher checkout) dan voucher platform publik.
import '../api/api_client.dart';
import '../models/voucher.dart';

/// Voucher pembeli: klaim, Voucher Saya, voucher platform publik.
class VoucherRepository {
  VoucherRepository(this._api);

  final ApiClient _api;

  List<Voucher> _list(Object? data) => ((data as List?) ?? const [])
      .map((e) => Voucher.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Klaim voucher [id] (`POST /me/vouchers/:id/claim`) dan kembalikan
  /// voucher terbaru. Idempoten di server; `ApiException` 409 bila tidak
  /// tersedia / kuota habis.
  Future<Voucher> claim(int id) async => Voucher.fromJson(
      (await _api.post('/me/vouchers/$id/claim')).data as Map<String, dynamic>);

  /// Voucher yang sudah diklaim (`GET /me/vouchers`). Tanpa argumen: layar
  /// Voucher Saya. Dengan data keranjang checkout: `usable` & `reason` mengikuti
  /// toko, subtotal, dan metode bayar. Argumen null tidak dikirim.
  Future<List<Voucher>> mine({
    int? merchantId,
    int? subtotal,
    String? paymentMethod,
  }) async {
    final query = <String, String>{
      'merchant_id': ?merchantId?.toString(),
      'subtotal': ?subtotal?.toString(),
      'payment_method': ?paymentMethod,
    };
    return _list(
        (await _api.get('/me/vouchers', query: query.isEmpty ? null : query))
            .data);
  }

  /// Voucher platform publik yang bisa diklaim (`GET /vouchers/platform`).
  Future<List<Voucher>> platform() async =>
      _list((await _api.get('/vouchers/platform')).data);
}
