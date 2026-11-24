import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/data/cart_store.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

  group('keranjang tersimpan di perangkat (tahan muat ulang web)', () {
    late SharedPreferencesAsync prefs;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = SharedPreferencesAsync();
    });

    /// Keranjang baru dari penyimpanan yang sama, seperti setelah halaman dimuat ulang.
    Future<CartProvider> reloadedCart() async {
      final cart = CartProvider(store: CartStore(prefs));
      await cart.restore();
      return cart;
    }

    test('tambah -> muat ulang -> isi, jumlah, opsi, dan data menu sama', () async {
      final cart = CartProvider(store: CartStore(prefs));
      final menu = ProductModel.fromJson({
        'id': 7,
        'name': 'Nasi Box',
        'price': 15000,
        'image_url': 'https://x.test/7.jpg',
        'is_preorder': true,
        'preorder_days': 2,
        'merchant': {
          'id': 3,
          'slug': 'dapur',
          'business_name': 'Dapur',
          'is_open': true,
          'pickup_points': [
            {'id': 9, 'name': 'Perpustakaan'},
          ],
        },
        'options': [
          {'id': 1, 'name': 'Pedas', 'extra_price': 2000},
        ],
      });
      cart.add(menu, option: menu.options.first, qty: 2);
      cart.add(menu);
      await pumpEventQueue();

      final reloaded = await reloadedCart();
      expect(reloaded.items.map((item) => item.key), ['7:1', '7:0']);
      expect(reloaded.items.map((item) => item.qty), [2, 1]);
      expect(reloaded.count, 3);
      expect(reloaded.merchantId, 3);
      expect(reloaded.maxPreorderDays, 2);
      final line = reloaded.items.first;
      expect(line.option!.name, 'Pedas');
      expect(line.estimatedLineTotal, 34000);
      expect(line.menu.name, 'Nasi Box');
      expect(line.menu.imageUrl, 'https://x.test/7.jpg');
      expect(line.menu.merchant.pickupPoints.single.name, 'Perpustakaan');
      expect(reloaded.toQuoteItems(), cart.toQuoteItems());
    });

    test('ubah jumlah dan hapus baris ikut tersimpan', () async {
      final cart = CartProvider(store: CartStore(prefs));
      cart.add(_menu(1));
      cart.add(_menu(2));
      cart.setQty('1:0', 5);
      cart.remove('2:0');
      await pumpEventQueue();

      final reloaded = await reloadedCart();
      expect(reloaded.items.map((item) => item.key), ['1:0']);
      expect(reloaded.items.single.qty, 5);
    });

    for (final (label, raw) in [
      ('JSON rusak', '{"v":1,"items":[{'),
      ('versi lama', '{"v":0,"items":[]}'),
      ('bukan objek', '[1,2]'),
      ('baris tanpa menu', '{"v":1,"items":[{"qty":1}]}'),
      (
        'opsi tidak ada',
        '{"v":1,"items":[{"menu":{"id":1,"name":"M","price":1,"merchant":'
            '{"id":1,"slug":"a","business_name":"A","is_open":true}},'
            '"option_id":5,"qty":1}]}',
      ),
    ]) {
      test('data tersimpan $label: keranjang kosong tanpa galat, data dibuang', () async {
        await prefs.setString(CartStore.storageKey, raw);
        final reloaded = await reloadedCart();
        expect(reloaded.items, isEmpty);
        expect(await prefs.getString(CartStore.storageKey), isNull);
      });
    }

    test('dikosongkan (mis. setelah pesanan dibuat): data tersimpan dihapus', () async {
      final cart = CartProvider(store: CartStore(prefs));
      cart.add(_menu(1));
      await pumpEventQueue();
      expect(await prefs.getString(CartStore.storageKey), isNotNull);

      cart.clear();
      await pumpEventQueue();
      expect(await prefs.getString(CartStore.storageKey), isNull);
      expect((await reloadedCart()).items, isEmpty);
    });

    test('Idempotency-Key ikut tersimpan; berubah bila isi keranjang berubah', () async {
      final cart = CartProvider(store: CartStore(prefs));
      cart.add(_menu(1));
      final key = cart.idempotencyKey;
      await pumpEventQueue();

      // Muat ulang sebelum mengulang checkout: kunci yang sama dipakai lagi.
      final reloaded = await reloadedCart();
      expect(reloaded.idempotencyKey, key);

      // Isi berubah: kunci lama tidak tersimpan lagi, kunci baru dibuat.
      reloaded.setQty('1:0', 2);
      await pumpEventQueue();
      final afterChange = await reloadedCart();
      expect(afterChange.items.single.qty, 2);
      final newKey = afterChange.idempotencyKey;
      expect(newKey, isNot(key));
      await pumpEventQueue();
      expect((await reloadedCart()).idempotencyKey, newKey);
    });

    test('kunci tersimpan yang bukan teks: data dibuang', () async {
      final raw = CartStore.encode((CartProvider()..add(_menu(1))).items)
          .replaceFirst('"v":1,', '"v":1,"idem":5,');
      await prefs.setString(CartStore.storageKey, raw);
      expect((await reloadedCart()).items, isEmpty);
      expect(await prefs.getString(CartStore.storageKey), isNull);
    });

    test('perubahan selama data dibaca tidak ditimpa data lama', () async {
      await prefs.setString(
          CartStore.storageKey, CartStore.encode((CartProvider()..add(_menu(1))).items));
      final cart = CartProvider(store: CartStore(prefs));
      final restoring = cart.restore();
      cart.add(_menu(2));
      await restoring;
      expect(cart.items.map((item) => item.key), ['2:0']);
    });
  });
}
