import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List _items = [];

  List get items => _items;

  int get itemCount =>
      _items.fold<int>(0, (sum, item) => sum + (item.quantity as int));

  double get totalPrice => _items.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );

  void addToCart(CartItem newItem) {
    final index = _items.indexWhere((item) => item.id == newItem.id);
    if (index >= 0) {
      _items[index].quantity += 1;
    } else {
      _items.add(newItem);
    }
    notifyListeners();
  }

  void removeFromCart(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}