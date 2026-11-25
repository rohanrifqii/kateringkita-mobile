// Penyimpanan isi keranjang di perangkat (SharedPreferences, berupa JSON berversi) supaya keranjang
// tetap ada setelah halaman web dimuat ulang (mis. Chrome Android membuang tab yang ditinggal ke
// aplikasi lain). Dipakai CartProvider: ditulis setiap isi keranjang berubah, dibaca sekali saat aplikasi dibuka.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';

/// Isi keranjang yang dibaca dari perangkat: barisnya dan Idempotency-Key checkout (null bila belum dibuat).
typedef SavedCart = ({List<CartItem> items, String? idempotencyKey});

/// Isi keranjang di perangkat dalam bentuk
/// `{"v":1,"idem":"<kunci>","items":[{"menu":{...},"option_id":1,"qty":2}]}`.
/// Menu disimpan lengkap (bentuk JSON API) supaya keranjang bisa dibangun ulang tanpa memanggil backend;
/// `idem` (Idempotency-Key checkout, opsional) disimpan supaya mengulang checkout setelah halaman
/// dimuat ulang tidak membuat pesanan ganda.
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
  /// @returns baris keranjang dan kuncinya yang tersimpan; baris kosong tanpa kunci
  ///   bila belum ada data, datanya rusak atau usang, atau penyimpanan tidak bisa dibaca.
  Future<SavedCart> load() async {
    const SavedCart empty = (items: [], idempotencyKey: null);
    try {
      final raw = await _prefs.getString(storageKey);
      if (raw == null) return empty;
      final saved = decode(raw);
      if (saved == null) await _prefs.remove(storageKey);
      return saved ?? empty;
    } catch (_) {
      return empty;
    }
  }

  /// Menyimpan [items] sebagai isi keranjang; daftar kosong menghapus data tersimpan.
  /// Galat penyimpanan didiamkan (keranjang di memori tetap benar).
  ///
  /// @param items isi keranjang saat ini.
  /// @param idempotencyKey Idempotency-Key checkout untuk isi ini, atau null bila belum dibuat.
  Future<void> save(List<CartItem> items, {String? idempotencyKey}) async {
    try {
      if (items.isEmpty) {
        await _prefs.remove(storageKey);
      } else {
        await _prefs.setString(
          storageKey,
          encode(items, idempotencyKey: idempotencyKey),
        );
      }
    } catch (_) {
      // Penyimpanan penuh/diblokir: keranjang hanya hilang bila halaman dimuat ulang.
    }
  }

  /// Mengubah [items] menjadi teks JSON berversi.
  ///
  /// @param items isi keranjang.
  /// @param idempotencyKey Idempotency-Key checkout; tidak ditulis bila null.
  /// @returns teks JSON `{"v":1,"idem":...,"items":[...]}`.
  static String encode(List<CartItem> items, {String? idempotencyKey}) =>
      jsonEncode({
        'v': formatVersion,
        'idem': ?idempotencyKey,
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
  /// @returns baris keranjang dan kuncinya; null bila teksnya rusak, versinya bukan
  ///   [formatVersion], ada baris atau kunci yang tidak sah, atau barisnya dari lebih dari satu toko.
  static SavedCart? decode(String raw) {
    try {
      // 1. Pastikan bentuk luar dan versinya cocok.
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['v'] != formatVersion) return null;
      final lines = decoded['items'];
      final idempotencyKey = decoded['idem'];
      if (lines is! List) return null;
      if (idempotencyKey != null && idempotencyKey is! String) return null;
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
      if (merchantIds.length > 1) return null;
      return (items: items, idempotencyKey: idempotencyKey as String?);
    } catch (_) {
      return null; // JSON rusak, kolom hilang/salah tipe, atau opsi tidak ditemukan.
    }
  }
}
