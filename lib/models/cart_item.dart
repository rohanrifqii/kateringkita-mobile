// Model satu baris isi keranjang belanja (disimpan di memori oleh CartProvider, tidak dikirim apa adanya
// ke backend; CartProvider.toQuoteItems yang mengubahnya ke format API).
import 'product_model.dart';

/// Satu baris keranjang: menu + opsi (opsional) + jumlah.
class CartItem {
  final ProductModel menu;
  final MenuOption? option;
  int qty;

  CartItem({required this.menu, this.option, this.qty = 1});

  /// Kunci unik baris: `idMenu:idOpsi` (0 bila tanpa opsi). Menu yang sama dengan opsi
  /// berbeda menjadi baris terpisah.
  String get key => '${menu.id}:${option?.id ?? 0}';

  /// Estimasi (harga menu + tambahan opsi) × jumlah, untuk tampilan sebelum quote;
  /// harga resmi dari server.
  int get estimatedLineTotal => (menu.price + (option?.extraPrice ?? 0)) * qty;
}
