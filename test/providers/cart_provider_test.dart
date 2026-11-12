import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';

ProductModel _menu(int id,
        {int merchant = 1,
        bool preorder = false,
        int days = 0,
        List<Map<String, dynamic>> options = const [
          {'id': 1, 'name': 'Pedas', 'extra_price': 2000},
          {'id': 2, 'name': 'Biasa', 'extra_price': 0},
        ]}) =>
    ProductModel.fromJson({
      'id': id,
      'name': 'M$id',
      'price': 10000,
      'is_preorder': preorder,
      'preorder_days': days,
      'merchant': {
        'id': merchant,
        'slug': 't$merchant',
        'business_name': 'T$merchant',
        'is_open': true,
      },
      'options': options,
    });

void main() {
  test('same menu + same option increments qty on one line', () {
    final c = CartProvider();
    final m = _menu(1);
    expect(c.add(m, option: m.options[0]), AddResult.added);
    c.add(m, option: m.options[0], qty: 2);
    expect(c.items.length, 1);
    expect(c.items.first.qty, 3);
    expect(c.count, 3);
    expect(c.merchantId, 1);
    expect(c.items.first.estimatedLineTotal, 36000);
  });

  test('different option makes a second line', () {
    final c = CartProvider();
    final m = _menu(1);
    c.add(m, option: m.options[0]);
    c.add(m, option: m.options[1]);
    c.add(m);
    expect(c.items.length, 3);
    expect(c.items.map((i) => i.key), ['1:1', '1:2', '1:0']);
  });

  test('other merchant returns differentMerchant and leaves cart', () {
    final c = CartProvider();
    c.add(_menu(1));
    expect(c.add(_menu(2, merchant: 2)), AddResult.differentMerchant);
    expect(c.items.length, 1);
    expect(c.merchantId, 1);
  });

  test('replaceWith clears then adds', () {
    final c = CartProvider();
    c.add(_menu(1));
    c.replaceWith(_menu(2, merchant: 2), qty: 2);
    expect(c.items.length, 1);
    expect(c.merchantId, 2);
    expect(c.count, 2);
  });

  test('setQty 0 removes; remove and clear work', () {
    final c = CartProvider();
    c.add(_menu(1));
    c.add(_menu(2));
    c.setQty('1:0', 5);
    expect(c.items.first.qty, 5);
    c.setQty('1:0', 0);
    expect(c.items.length, 1);
    c.remove('2:0');
    expect(c.items, isEmpty);
    expect(c.merchantId, isNull);
    c.add(_menu(3));
    c.clear();
    expect(c.count, 0);
  });

  test('hasPreorder and maxPreorderDays', () {
    final c = CartProvider();
    expect(c.hasPreorder, isFalse);
    expect(c.maxPreorderDays, 0);
    c.add(_menu(1));
    c.add(_menu(2, preorder: true, days: 2));
    c.add(_menu(3, preorder: true, days: 5));
    expect(c.hasPreorder, isTrue);
    expect(c.maxPreorderDays, 5);
  });

  test('toQuoteItems shape', () {
    final c = CartProvider();
    final m = _menu(1);
    c.add(m, option: m.options[0], qty: 2);
    c.add(_menu(2));
    expect(c.toQuoteItems(), [
      {'menu_id': 1, 'qty': 2, 'option_ids': [1]},
      {'menu_id': 2, 'qty': 1, 'option_ids': <int>[]},
    ]);
  });

  test('idempotencyKey stabil sampai isi keranjang berubah', () {
    final c = CartProvider();
    final m = _menu(1);
    c.add(m);
    final k1 = c.idempotencyKey;
    expect(k1, isNotEmpty);
    expect(c.idempotencyKey, k1);

    String renewedBy(void Function() change) {
      final before = c.idempotencyKey;
      change();
      final after = c.idempotencyKey;
      expect(after, isNot(before));
      return after;
    }

    renewedBy(() => c.add(_menu(2)));
    renewedBy(() => c.setQty('2:0', 3));
    renewedBy(() => c.remove('2:0'));
    renewedBy(() => c.replaceWith(_menu(3, merchant: 3)));
    renewedBy(c.clear);

    // setQty dengan jumlah yang sama tidak mengubah isi.
    c.add(m);
    final same = c.idempotencyKey;
    c.setQty('1:0', 1);
    expect(c.idempotencyKey, same);
  });
}
