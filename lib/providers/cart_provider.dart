import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';

enum AddResult { added, differentMerchant }

/// Keranjang multi-menu untuk satu toko.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int? get merchantId => _items.isEmpty ? null : _items.first.menu.merchant.id;

  int get count => _items.fold(0, (s, i) => s + i.qty);

  bool get hasPreorder => _items.any((i) => i.menu.isPreorder);

  int get maxPreorderDays => _items
      .where((i) => i.menu.isPreorder)
      .fold(0, (m, i) => i.menu.preorderDays > m ? i.menu.preorderDays : m);

  AddResult add(ProductModel menu, {MenuOption? option, int qty = 1}) {
    if (_items.isNotEmpty && merchantId != menu.merchant.id) {
      return AddResult.differentMerchant;
    }
    _addLine(menu, option, qty);
    notifyListeners();
    return AddResult.added;
  }

  void replaceWith(ProductModel menu, {MenuOption? option, int qty = 1}) {
    _items.clear();
    _addLine(menu, option, qty);
    notifyListeners();
  }

  void _addLine(ProductModel menu, MenuOption? option, int qty) {
    final line = CartItem(menu: menu, option: option, qty: qty);
    final i = _items.indexWhere((e) => e.key == line.key);
    if (i >= 0) {
      _items[i].qty += qty;
    } else {
      _items.add(line);
    }
  }

  void setQty(String key, int qty) {
    if (qty <= 0) return remove(key);
    final i = _items.indexWhere((e) => e.key == key);
    if (i < 0) return;
    _items[i].qty = qty;
    notifyListeners();
  }

  void remove(String key) {
    _items.removeWhere((e) => e.key == key);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toQuoteItems() => [
        for (final i in _items)
          {
            'menu_id': i.menu.id,
            'qty': i.qty,
            'option_ids': i.option == null ? <int>[] : [i.option!.id],
          }
      ];
}
