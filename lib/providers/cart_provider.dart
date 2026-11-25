// Keranjang belanja, dibaca layar lewat Provider. Bila diberi CartStore (main.dart), isinya juga disimpan
// di perangkat supaya tetap ada setelah halaman web dimuat ulang. Isinya dikirim ke backend saat checkout
// lewat toQuoteItems() dan OrderRepository (POST /orders/quote, /orders).
import 'package:flutter/foundation.dart';
import '../api/idempotency.dart';
import '../data/cart_store.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';

/// Hasil [CartProvider.add]: berhasil ditambah, atau ditolak karena menu dari toko lain.
enum AddResult { added, differentMerchant }

/// Keranjang multi-menu untuk satu toko (semua baris harus dari toko yang sama).
class CartProvider extends ChangeNotifier {
  /// [store] menyimpan isi keranjang di perangkat setiap kali berubah; null = hanya di memori.
  CartProvider({this._store});

  final CartStore? _store;
  final List<CartItem> _items = [];
  String? _idemKey;

  /// True setelah isi keranjang pernah diubah; [restore] lalu tidak menimpanya dengan data lama.
  bool _changedSinceStart = false;

  /// Isi keranjang (salinan tak-bisa-diubah; ubah lewat metode provider ini).
  List<CartItem> get items => List.unmodifiable(_items);

  /// Idempotency-Key untuk membuat pesanan dari isi keranjang saat ini.
  /// Dibuat saat pertama dibutuhkan dan tetap sama (juga bila layar checkout
  /// ditutup lalu dibuka lagi, atau halaman web dimuat ulang) sampai isi
  /// keranjang berubah atau dikosongkan. Kunci baru langsung disimpan bersama keranjang.
  String get idempotencyKey {
    final existingKey = _idemKey;
    if (existingKey != null) return existingKey;
    final createdKey = _idemKey = newIdempotencyKey();
    // Keranjang kosong tidak disimpan (dan tidak boleh menghapus data yang belum dipulihkan).
    if (_items.isNotEmpty) _store?.save(_items, idempotencyKey: createdKey);
    return createdKey;
  }

  /// Isi keranjang berubah: niat checkout baru, kunci lama tidak berlaku; isi baru disimpan ke perangkat.
  void _changed() {
    _idemKey = null;
    _changedSinceStart = true;
    _store?.save(_items);
    notifyListeners();
  }

  /// Selesai saat [restore] selesai (langsung selesai bila [restore] belum dipanggil). Ditunggu
  /// layar yang membaca isi keranjang saat halaman web dimuat ulang, mis. checkout.
  Future<void> get restored => _restoring;
  Future<void> _restoring = Future<void>.value();

  /// Mengisi keranjang dengan isi yang tersimpan di perangkat (dipanggil sekali saat aplikasi dibuka).
  /// Tidak melakukan apa-apa bila tidak ada [CartStore] atau keranjang sudah diubah selama data dibaca.
  Future<void> restore() => _restoring = _restoreFromStore();

  // Isi [restore]: baca data tersimpan lalu terapkan bila keranjang belum diubah.
  Future<void> _restoreFromStore() async {
    final store = _store;
    if (store == null) return;
    final saved = await store.load();
    if (_changedSinceStart || saved.items.isEmpty) return;
    _items.addAll(saved.items);
    _idemKey = saved.idempotencyKey;
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
