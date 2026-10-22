import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage untuk menyimpan produk yang disukai (favorit/liked)
/// menggunakan SharedPreferences.
class LikedStore {
  static final _prefs = SharedPreferencesAsync();
  static const _likedKey = 'liked_products_list';
  static const _seededKey = 'liked_products_seeded';

  // Default produk yang disukai saat pertama kali aplikasi dibuka
  static const List<String> defaultLikedIds = [
    'prod-001', // Lumpia Diego
    'prod-002', // Martabak Manis
    'prod-004', // Donat Surgawi
    'prod-005', // Risoles Bu Tima
  ];

  static final ValueNotifier<Set<String>> likedNotifier =
      ValueNotifier<Set<String>>(defaultLikedIds.toSet());

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final isSeeded = await _prefs.getBool(_seededKey) ?? false;
      if (isSeeded) {
        final list = await _prefs.getStringList(_likedKey);
        likedNotifier.value = (list ?? []).toSet();
      } else {
        await _prefs.setStringList(_likedKey, defaultLikedIds);
        await _prefs.setBool(_seededKey, true);
        likedNotifier.value = defaultLikedIds.toSet();
      }
    } catch (_) {
      likedNotifier.value = defaultLikedIds.toSet();
    }
    _initialized = true;
  }

  static bool isLiked(String productId) {
    return likedNotifier.value.contains(productId);
  }

  static Future<bool> toggleLike(String productId) async {
    await init();
    final current = Set<String>.from(likedNotifier.value);
    final nowLiked = !current.contains(productId);

    if (nowLiked) {
      current.add(productId);
    } else {
      current.remove(productId);
    }

    likedNotifier.value = current;
    await _prefs.setBool(_seededKey, true);
    await _prefs.setStringList(_likedKey, current.toList());
    return nowLiked;
  }
}
