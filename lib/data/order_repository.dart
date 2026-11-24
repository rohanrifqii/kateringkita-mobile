import '../api/api_client.dart';
import '../models/order_api_model.dart';

/// Pesanan pelanggan lewat REST backend.
class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  String _path(String code) => '/orders/${Uri.encodeComponent(code)}';

  OrderApiModel _order(ApiResponse res) =>
      OrderApiModel.fromJson(res.data as Map<String, dynamic>);

  Future<Quote> quote(Map<String, dynamic> body) async {
    final res = await _api.post('/orders/quote', body: body);
    return Quote.fromJson(res.data as Map<String, dynamic>);
  }

  /// [idempotencyKey] harus dipakai ulang saat mengulang permintaan yang
  /// sama (mis. setelah timeout) agar tidak tercipta pesanan ganda.
  Future<OrderApiModel> create(Map<String, dynamic> body,
          {required String idempotencyKey}) async =>
      _order(await _api.post('/orders',
          body: body, headers: {'Idempotency-Key': idempotencyKey}));

  Future<OrderApiModel> get(String code) async =>
      _order(await _api.get(_path(code)));

  Future<OrderApiModel> createVa(String code, String bank) async =>
      _order(await _api.post('${_path(code)}/va', body: {'bank': bank}));

  Future<OrderApiModel> startOnline(String code) async =>
      _order(await _api.post('${_path(code)}/online'));

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

  Future<OrderApiModel> cancel(String code, {String? reason}) async =>
      _order(await _api.post('${_path(code)}/cancel',
          body: {'reason': ?reason}));

  Future<OrderApiModel> complete(String code) async =>
      _order(await _api.post('${_path(code)}/complete'));

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

  Future<({Map<String, dynamic> request, Quote quote})> reorder(
      String code) async {
    final res = await _api.post('${_path(code)}/reorder');
    final d = res.data as Map<String, dynamic>;
    return (
      request: d['request'] as Map<String, dynamic>,
      quote: Quote.fromJson(d['quote'] as Map<String, dynamic>),
    );
  }

  /// Mengembalikan `reviewed_menu_ids`.
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
