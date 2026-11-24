// Penyimpanan isi keranjang di perangkat (SharedPreferences, berupa JSON berversi) supaya keranjang
// tetap ada setelah halaman web dimuat ulang (mis. Chrome Android membuang tab yang ditinggal ke
// aplikasi lain). Dipakai CartProvider: ditulis setiap isi keranjang berubah, dibaca sekali saat aplikasi dibuka.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';

/// Isi keranjang di perangkat dalam bentuk `{"v":1,"items":[{"menu":{...},"option_id":1,"qty":2}]}`.
/// Menu disimpan lengkap (bentuk JSON API) supaya keranjang bisa dibangun ulang tanpa memanggil backend.
class CartStore {
  CartStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Kunci SharedPreferences untuk isi keranjang.
  static const storageKey = 'cart';

  /// Versi format yang ditulis sekarang; data dengan versi lain dianggap usang lalu dibuang.
  static const formatVersion = 1;

  /// Memuat isi keranjang yang tersimpan.
  ///
  /// Data rusak atau versi lama dihapus dari perangkat supaya tidak dibaca lagi.
  /// Tidak pernah melempar galat.
  ///
  /// @returns baris keranjang yang tersimpan; daftar kosong bila belum ada data,
  ///   datanya rusak atau usang, atau penyimpanan tidak bisa dibaca.
  Future<List<CartItem>> load() async {
    try {
      final raw = await _prefs.getString(storageKey);
      if (raw == null) return [];
      final items = decode(raw);
      if (items == null) await _prefs.remove(storageKey);
      return items ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Menyimpan [items] sebagai isi keranjang; daftar kosong menghapus data tersimpan.
  /// Galat penyimpanan didiamkan (keranjang di memori tetap benar).
  ///
  /// @param items isi keranjang saat ini.
  Future<void> save(List<CartItem> items) async {
    try {
      if (items.isEmpty) {
        await _prefs.remove(storageKey);
      } else {
        await _prefs.setString(storageKey, encode(items));
      }
    } catch (_) {
      // Penyimpanan penuh/diblokir: keranjang hanya hilang bila halaman dimuat ulang.
    }
  }

  /// Mengubah [items] menjadi teks JSON berversi.
  ///
  /// @param items isi keranjang.
  /// @returns teks JSON `{"v":1,"items":[...]}`.
  static String encode(List<CartItem> items) => jsonEncode({
        'v': formatVersion,
        'items': [
          for (final item in items)
            {
              'menu': item.menu.toJson(),
              'option_id': item.option?.id,
              'qty': item.qty,
            },
        ],
      });

  /// Mengurai teks JSON hasil [encode].
  ///
  /// @param raw teks yang tersimpan di perangkat.
  /// @returns baris keranjang; null bila teksnya rusak, versinya bukan
  ///   [formatVersion], ada baris yang tidak sah, atau barisnya dari lebih dari satu toko.
  static List<CartItem>? decode(String raw) {
    try {
      // 1. Pastikan bentuk luar dan versinya cocok.
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['v'] != formatVersion) return null;
      final lines = decoded['items'];
      if (lines is! List) return null;
      // 2. Bangun ulang tiap baris; satu baris tidak sah membatalkan semuanya.
      final items = <CartItem>[];
      for (final line in lines) {
        final menu = ProductModel.fromJson(line['menu'] as Map<String, dynamic>);
        final optionId = line['option_id'] as int?;
        final quantity = line['qty'] as int;
        if (quantity <= 0) return null;
        final option = optionId == null
            ? null
            : menu.options.firstWhere((candidate) => candidate.id == optionId);
        items.add(CartItem(menu: menu, option: option, qty: quantity));
      }
      // 3. Keranjang hanya boleh berisi menu dari satu toko.
      final merchantIds = items.map((item) => item.menu.merchant.id).toSet();
      return merchantIds.length > 1 ? null : items;
    } catch (_) {
      return null; // JSON rusak, kolom hilang/salah tipe, atau opsi tidak ditemukan.
    }
  }
}
