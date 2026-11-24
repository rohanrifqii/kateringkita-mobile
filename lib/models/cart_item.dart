import 'product_model.dart';

/// Satu baris keranjang: menu + opsi (opsional) + jumlah.
class CartItem {
  final ProductModel menu;
  final MenuOption? option;
  int qty;

  CartItem({required this.menu, this.option, this.qty = 1});

  String get key => '${menu.id}:${option?.id ?? 0}';

  /// Estimasi untuk tampilan sebelum quote; harga resmi dari server.
  int get estimatedLineTotal => (menu.price + (option?.extraPrice ?? 0)) * qty;
}
