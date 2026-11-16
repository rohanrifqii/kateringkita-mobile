import 'product_model.dart';

/// Satu baris menu di keranjang / checkout (menu + jumlah porsi).
class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  String get id => product.id;
  double get subtotal => product.price * quantity;

  CartItem copy() => CartItem(product: product, quantity: quantity);
}

/// Argumen untuk membuka CheckoutScreen dengan banyak menu sekaligus.
///
/// [fromCart] = true berarti item berasal dari keranjang global, sehingga
/// perubahan jumlah di checkout ikut disinkronkan ke keranjang dan keranjang
/// dikosongkan setelah pembayaran dikonfirmasi.
class CheckoutRequest {
  final List<CartItem> items;
  final bool fromCart;

  const CheckoutRequest({required this.items, this.fromCart = false});
}
