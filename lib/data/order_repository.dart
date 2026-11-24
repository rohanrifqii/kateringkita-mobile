// Repository pesanan pelanggan: hitung harga (quote), buat pesanan, bayar (VA/Midtrans Snap/QRIS), daftar,
// batal, selesai, pesan WhatsApp, pesan lagi, dan ulasan. Dipakai layar checkout, pembayaran, dan pesanan.
import '../api/api_client.dart';
import '../models/order_api_model.dart';

/// Pesanan pelanggan lewat REST backend. Semua metode melempar [ApiException] bila gagal.
class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  // Path dasar satu pesanan; kode di-encode agar aman dipakai di URL.
  String _path(String code) => '/orders/${Uri.encodeComponent(code)}';

  OrderApiModel _order(ApiResponse res) =>
      OrderApiModel.fromJson(res.data as Map<String, dynamic>);

  /// POST /orders/quote: menghitung harga resmi dari server untuk [body] (isi keranjang, titik
  /// ambil, promo, dll.) tanpa membuat pesanan.
  Future<Quote> quote(Map<String, dynamic> body) async {
    final res = await _api.post('/orders/quote', body: body);
    return Quote.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /orders: membuat pesanan dari [body].
  ///
  /// [idempotencyKey] harus dipakai ulang saat mengulang permintaan yang
  /// sama (mis. setelah timeout) agar tidak tercipta pesanan ganda.
  Future<OrderApiModel> create(Map<String, dynamic> body,
          {required String idempotencyKey}) async =>
      _order(await _api.post('/orders',
          body: body, headers: {'Idempotency-Key': idempotencyKey}));

  /// GET /orders/:code: data terbaru satu pesanan (dipakai juga untuk memantau pembayaran).
  Future<OrderApiModel> get(String code) async =>
      _order(await _api.get(_path(code)));

  /// POST /orders/:code/va: membuat Virtual Account Midtrans di [bank] (kode bank, mis. `bca`).
  /// Pesanan yang dikembalikan memuat nomor VA.
  Future<OrderApiModel> createVa(String code, String bank) async =>
      _order(await _api.post('${_path(code)}/va', body: {'bank': bank}));

  /// POST /orders/:code/online: memulai pembayaran Midtrans Snap (QRIS / e-wallet).
  /// Pesanan yang dikembalikan memuat tautan pembayaran (`payment_url`).
  Future<OrderApiModel> startOnline(String code) async =>
      _order(await _api.post('${_path(code)}/online'));

  /// POST /orders/:code/qris: membuat kode QRIS yang ditampilkan langsung di aplikasi.
  /// Idempoten di server (satu QR per pesanan).
  Future<OrderApiModel> startQris(String code) async =>
      _order(await _api.post('${_path(code)}/qris'));

  /// GET /me/orders: satu halaman pesanan milik pembeli untuk [tab] (mis. `active`,
  /// `completed`, `cancelled`), disaring kata kunci [q] bila diisi. `total` dari `meta.total`,
  /// atau jumlah item halaman ini bila `meta` tidak ada.
  Future<({List<OrderApiModel> items, int total})> list({
    required String tab,
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get('/me/orders', query: {
      'tab': tab,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'limit': '$limit',
    });
    final items = (res.data as List)
        .map((e) => OrderApiModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items: items,
      total: (res.meta?['total'] as num?)?.toInt() ?? items.length,
    );
  }

  /// POST /orders/:code/cancel: membatalkan pesanan; [reason] hanya dikirim bila tidak null.
  Future<OrderApiModel> cancel(String code, {String? reason}) async =>
      _order(await _api.post('${_path(code)}/cancel',
          body: {'reason': ?reason}));

  /// POST /orders/:code/complete: menandai pesanan sudah diambil (selesai).
  Future<OrderApiModel> complete(String code) async =>
      _order(await _api.post('${_path(code)}/complete'));

  /// GET /orders/:code/whatsapp: pesan WhatsApp ke penjual yang disusun server.
  /// Mengembalikan nomor WA, isi pesan, dan tautan WhatsApp siap buka (string kosong bila tidak dikirim).
  Future<({String waNumber, String message, String url})> whatsapp(
      String code) async {
    final res = await _api.get('${_path(code)}/whatsapp');
    final d = res.data as Map<String, dynamic>;
    return (
      waNumber: (d['wa_number'] as String?) ?? '',
      message: (d['message'] as String?) ?? '',
      url: (d['url'] as String?) ?? '',
    );
  }

  /// POST /orders/:code/reorder ("Pesan Lagi"): server menyusun ulang permintaan pesanan dari
  /// pesanan lama. Mengembalikan isi permintaan itu beserta quote harga terbarunya.
  Future<({Map<String, dynamic> request, Quote quote})> reorder(
      String code) async {
    final res = await _api.post('${_path(code)}/reorder');
    final d = res.data as Map<String, dynamic>;
    return (
      request: d['request'] as Map<String, dynamic>,
      quote: Quote.fromJson(d['quote'] as Map<String, dynamic>),
    );
  }

  /// POST /orders/:code/reviews: mengirim ulasan per menu (bintang + komentar opsional; komentar
  /// kosong tidak dikirim). Mengembalikan `reviewed_menu_ids`, yaitu id menu yang sudah diulas.
  Future<List<int>> review(String code,
      List<({int menuId, int rating, String? comment})> items) async {
    final res = await _api.post('${_path(code)}/reviews', body: {
      'items': [
        for (final i in items)
          {
            'menu_id': i.menuId,
            'rating': i.rating,
            if (i.comment != null && i.comment!.trim().isNotEmpty)
              'comment': i.comment!.trim(),
          }
      ],
    });
    final d = res.data as Map<String, dynamic>;
    return ((d['reviewed_menu_ids'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
  }
}
