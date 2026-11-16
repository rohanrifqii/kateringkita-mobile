import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';

/// Keranjang belanja. Aturan utama: isi keranjang HANYA boleh berasal dari
/// satu dapur/toko (seperti ShopeeFood / GoFood). Menambah menu dari dapur
/// lain harus lewat [replaceWith] setelah user mengkonfirmasi.
class CartProvider with ChangeNotifier {
  static const int maxQuantityPerItem = 5000;

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  /// Nama dapur pemilik keranjang saat ini (null jika keranjang kosong).
  String? get vendorName => _items.isEmpty ? null : _items.first.product.vendor;

  int get itemCount => _items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get totalPrice => _items.fold<double>(0, (sum, i) => sum + i.subtotal);

  int quantityOf(String productId) {
    final index = _items.indexWhere((i) => i.id == productId);
    return index >= 0 ? _items[index].quantity : 0;
  }

  /// True jika keranjang berisi menu dari dapur lain selain [vendor].
  bool belongsToOtherVendor(String vendor) =>
      _items.isNotEmpty && vendorName != vendor;

  /// Menambah [count] porsi. Mengembalikan false (tanpa mengubah apa pun) bila
  /// keranjang milik dapur lain atau jumlah sudah mencapai batas.
  bool add(ProductModel product, {int count = 1}) {
    if (belongsToOtherVendor(product.vendor)) return false;
    final index = _items.indexWhere((i) => i.id == product.id);
    if (index >= 0) {
      if (_items[index].quantity >= maxQuantityPerItem) return false;
      _items[index].quantity =
          (_items[index].quantity + count).clamp(1, maxQuantityPerItem);
    } else {
      _items.add(
        CartItem(
          product: product,
          quantity: count.clamp(1, maxQuantityPerItem),
        ),
      );
    }
    notifyListeners();
    return true;
  }

  /// Kosongkan keranjang lalu isi dengan [quantity] porsi [product] (ganti dapur).
  void replaceWith(ProductModel product, {int quantity = 1}) {
    _items
      ..clear()
      ..add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, maxQuantityPerItem),
        ),
      );
    notifyListeners();
  }

  /// Kurangi 1 porsi; item dihapus otomatis saat jumlahnya habis.
  void decrement(String productId) {
    final index = _items.indexWhere((i) => i.id == productId);
    if (index < 0) return;
    if (_items[index].quantity <= 1) {
      _items.removeAt(index);
    } else {
      _items[index].quantity -= 1;
    }
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final index = _items.indexWhere((i) => i.id == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity.clamp(1, maxQuantityPerItem);
    }
    notifyListeners();
  }

  /// Set jumlah porsi untuk [product] (menambahkan item baru jika belum ada).
  bool setProductQuantity(ProductModel product, int quantity) {
    if (belongsToOtherVendor(product.vendor)) return false;
    final index = _items.indexWhere((i) => i.id == product.id);
    if (quantity <= 0) {
      if (index >= 0) {
        _items.removeAt(index);
        notifyListeners();
      }
      return true;
    }
    final clamped = quantity.clamp(1, maxQuantityPerItem);
    if (index >= 0) {
      _items[index].quantity = clamped;
    } else {
      _items.add(CartItem(product: product, quantity: clamped));
    }
    notifyListeners();
    return true;
  }

  void remove(String productId) {
    _items.removeWhere((i) => i.id == productId);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
