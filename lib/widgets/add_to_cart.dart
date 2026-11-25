// Aksi "tambah ke keranjang" bersama untuk layar detail menu dan profil toko: menambah ke CartProvider
// dan menangani kasus keranjang berisi menu dari toko lain.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

/// Tambah [qty] [menu] (dengan [option] opsional) ke keranjang; bila toko beda, tanya dulu
/// lewat dialog lalu ganti keranjang bila pengguna memilih "Ya". Snackbar muncul bila berhasil.
Future<void> addToCartWithPrompt(
  BuildContext context,
  ProductModel menu, {
  MenuOption? option,
  int qty = 1,
}) async {
  final cart = context.read<CartProvider>();
  final messenger = ScaffoldMessenger.of(context);
  void toast() => messenger.showSnackBar(const SnackBar(
        content: Text('Ditambahkan ke keranjang'),
        duration: Duration(seconds: 1),
      ));

  if (cart.add(menu, option: option, qty: qty) == AddResult.added) {
    toast();
    return;
  }
  final replace = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: const Text(
          'Keranjang berisi menu dari toko lain. Kosongkan dan ganti?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya')),
      ],
    ),
  );
  if (replace == true) {
    cart.replaceWith(menu, option: option, qty: qty);
    toast();
  }
}
