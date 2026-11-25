// Keranjang belanja di memori (hilang saat aplikasi ditutup), dibaca layar lewat Provider. Isinya
// dikirim ke backend saat checkout lewat toQuoteItems() dan OrderRepository (POST /orders/quote, /orders).
import 'package:flutter/foundation.dart';
import '../api/idempotency.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';

/// Hasil [CartProvider.add]: berhasil ditambah, atau ditolak karena menu dari toko lain.
enum AddResult { added, differentMerchant }

/// Keranjang multi-menu untuk satu toko (semua baris harus dari toko yang sama).
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _idemKey;

  /// Isi keranjang (salinan tak-bisa-diubah; ubah lewat metode provider ini).
  List<CartItem> get items => List.unmodifiable(_items);

  /// Idempotency-Key untuk membuat pesanan dari isi keranjang saat ini.
  /// Dibuat saat pertama dibutuhkan dan tetap sama (juga bila layar checkout
  /// ditutup lalu dibuka lagi) sampai isi keranjang berubah atau dikosongkan.
  String get idempotencyKey => _idemKey ??= newIdempotencyKey();

  /// Isi keranjang berubah: niat checkout baru, kunci lama tidak berlaku.
  void _changed() {
    _idemKey = null;
    notifyListeners();
  }

  /// Id toko pemilik isi keranjang, atau null bila keranjang kosong.
  int? get merchantId => _items.isEmpty ? null : _items.first.menu.merchant.id;

  /// Total jumlah porsi (jumlah semua qty), dipakai lencana ikon keranjang.
  int get count => _items.fold(0, (s, i) => s + i.qty);

  /// True bila ada menu pre-order di keranjang.
  bool get hasPreorder => _items.any((i) => i.menu.isPreorder);

  /// Hari pre-order terpanjang di antara menu pre-order (0 bila tidak ada); menentukan
  /// waktu ambil paling awal di checkout.
  int get maxPreorderDays => _items
      .where((i) => i.menu.isPreorder)
      .fold(0, (m, i) => i.menu.preorderDays > m ? i.menu.preorderDays : m);

  /// Menambah [qty] [menu] (dengan [option] opsional). Baris yang sama digabung jumlahnya.
  /// Mengembalikan [AddResult.differentMerchant] tanpa mengubah keranjang bila menu dari toko lain.
  AddResult add(ProductModel menu, {MenuOption? option, int qty = 1}) {
    if (_items.isNotEmpty && merchantId != menu.merchant.id) {
      return AddResult.differentMerchant;
    }
    _addLine(menu, option, qty);
    _changed();
    return AddResult.added;
  }

  /// Mengosongkan keranjang lalu mengisinya dengan [menu] saja (dipakai setelah pengguna setuju
  /// mengganti keranjang dari toko lain).
  void replaceWith(ProductModel menu, {MenuOption? option, int qty = 1}) {
    _items.clear();
    _addLine(menu, option, qty);
    _changed();
  }

  // Menambah baris baru, atau menambah jumlah bila baris dengan kunci yang sama sudah ada.
  void _addLine(ProductModel menu, MenuOption? option, int qty) {
    final line = CartItem(menu: menu, option: option, qty: qty);
    final i = _items.indexWhere((e) => e.key == line.key);
    if (i >= 0) {
      _items[i].qty += qty;
    } else {
      _items.add(line);
    }
  }

  /// Mengubah jumlah baris [key] menjadi [qty]; jumlah 0 atau kurang menghapus baris itu.
  void setQty(String key, int qty) {
    if (qty <= 0) return remove(key);
    final i = _items.indexWhere((e) => e.key == key);
    if (i < 0 || _items[i].qty == qty) return;
    _items[i].qty = qty;
    _changed();
  }

  /// Menghapus baris dengan kunci [key].
  void remove(String key) {
    _items.removeWhere((e) => e.key == key);
    _changed();
  }

  /// Mengosongkan keranjang (mis. setelah pesanan dibuat atau pengguna keluar).
  void clear() {
    _items.clear();
    _changed();
  }

  /// Isi keranjang dalam format `items` API: `menu_id`, `qty`, dan `option_ids`.
  List<Map<String, dynamic>> toQuoteItems() => [
        for (final i in _items)
          {
            'menu_id': i.menu.id,
            'qty': i.qty,
            'option_ids': i.option == null ? <int>[] : [i.option!.id],
          }
      ];
}
